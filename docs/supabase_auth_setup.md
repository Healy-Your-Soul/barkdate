# Supabase auth setup for BarkDate

Everything you need to configure in Supabase so the onboarding flow works:

1. **Site URL + Redirect URLs** so verification emails and OAuth return to the right place.
2. **Email confirmations** turned ON.
3. **`handle_new_user` trigger** so `public.users.name` is populated from signup metadata (it likely already is, we double-check).
4. **Native deep-link scheme** (iOS / Android) so tapping an email link reopens the app.

Good news: your CLI is installed and linked. The Dashboard steps still work as a fallback and are easier for auth-side knobs.

> Checked 2026-04-19: CLI version `2.90.0`, logged in, project linked as `caottaawpnocywayjmyl` (Bark). `supabase/config.toml` present. If that stops being true run `supabase login` then `supabase link --project-ref caottaawpnocywayjmyl`.

---

## 0. The two kinds of "config" and when to use which

| Thing you want to change | Tool | Where it lives |
| --- | --- | --- |
| Tables, columns, triggers, RLS | SQL in `supabase/migrations/*.sql` pushed via CLI, or pasted in Dashboard > SQL Editor | `public` schema in your Postgres database |
| Site URL, Redirect URLs, email templates, OAuth providers, signup rules | Dashboard > Authentication pages, or `supabase/config.toml` + CLI | Supabase's `auth` service (gotrue) |

Both the Dashboard and the CLI can change most of these. The Dashboard is quicker for one-off auth knobs; the CLI is better when you want the config checked into git.

---

## 1. Set Site URL + Redirect URLs (REQUIRED)

These decide where verification emails and OAuth logins are allowed to return to. Without them, clicking the email link just opens a browser tab with an error.

### What to set

- **Site URL** = the default place emails redirect to. Pick **one** value.
  - For development today (Flutter on web at `http://localhost:50342`): `http://localhost:50342`
  - For production (when you deploy): `https://your-production-domain.com`

- **Redirect URLs** = an allowlist of everywhere else the Site URL value isn't. Add all of:
  - `http://localhost:50342` (Flutter web local dev - the port can change, add the current one)
  - `http://127.0.0.1:50342`
  - `http://localhost:62747` and `http://127.0.0.1:62747` (already in your `config.toml`; keep them)
  - `io.supabase.bark://login-callback/` (iOS / Android deep link - see section 4)
  - When you deploy, add your prod web URL too.

### Option A - Dashboard (fastest)

1. Open <https://supabase.com/dashboard/project/caottaawpnocywayjmyl>.
2. Left sidebar, **Authentication > URL Configuration**.
3. Fill in **Site URL** with the dev URL above.
4. In **Redirect URLs**, click Add URL and paste each of the values above, one per line.
5. Click **Save**.

### Option B - CLI + `config.toml`

Your local `supabase/config.toml` currently has (lines 120-122):

```toml
[auth]
site_url = "http://localhost:62747"
additional_redirect_urls = ["http://127.0.0.1:62747", "http://localhost:62747", "http://127.0.0.1:54321/auth/v1/callback"]
```

Update to:

```toml
[auth]
site_url = "http://localhost:50342"
additional_redirect_urls = [
  "http://127.0.0.1:50342",
  "http://localhost:50342",
  "http://127.0.0.1:62747",
  "http://localhost:62747",
  "http://127.0.0.1:54321/auth/v1/callback",
  "io.supabase.bark://login-callback/",
]
```

Then push to the linked remote project:

```bash
supabase config push
```

Verify by running `supabase config show auth.site_url` or just opening the Dashboard URL Configuration page.

> Dashboard wins in case of conflict when `supabase config push` is not run - Dashboard changes can be overwritten by a later `config push` of a stale `config.toml`. Pick one source of truth (recommended: `config.toml` + CLI, so it's in git).

---

## 2. Turn ON email confirmations (REQUIRED)

Your `supabase/config.toml` line 173 says `enable_confirmations = false`, which means users can sign in **without** verifying their email. We want the opposite.

### Option A - Dashboard

1. Supabase Dashboard > **Authentication > Providers > Email**.
2. Scroll to **Confirm email** and toggle it **ON**.
3. **Save**.

### Option B - CLI + `config.toml`

Edit `supabase/config.toml` line 173:

```toml
[auth.email]
enable_confirmations = true
```

Then:

```bash
supabase config push
```

After this, `Supabase.auth.signUp(...)` will return a user whose `email_confirmed_at` is `NULL` until they click the verification link. Our Sprint 2 code reads that field to decide what to show next.

---

## 3. Make sure `public.users` gets populated on signup

When someone signs up with email+password, Supabase creates a row in `auth.users`. Our app expects a matching row in `public.users` (with `name` from signup metadata). You already have a trigger that does this - we just verify it's there.

### Check what's installed

```bash
supabase db dump --linked --schema auth,public --data-only=false 2>/dev/null | grep -n "handle_new_user\|on_auth_user_created\|sync_firebase_user" | head -20
```

Or in the Dashboard: **Database > Triggers** and look on the `auth.users` table for a trigger named `on_auth_user_created` (or similar).

If one exists and references a function that inserts into `public.users`, you're done - skip to section 4.

### If no trigger exists, install this migration

Save as `supabase/migrations/20260419120000_handle_new_user.sql`:

```sql
-- Ensure public.users gets a row whenever an auth.users row is created.
-- Pulls name from the signup metadata (passed as signUp(data: {'name': ...})).
-- Safe to re-run: uses CREATE OR REPLACE and DROP IF EXISTS.

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.users (id, email, name)
  values (
    new.id,
    new.email,
    coalesce(nullif(trim(new.raw_user_meta_data->>'name'), ''), '')
  )
  on conflict (id) do update
    set name = coalesce(
      nullif(trim(excluded.name), ''),
      public.users.name
    );
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;

create trigger on_auth_user_created
  after insert on auth.users
  for each row
  execute function public.handle_new_user();
```

Push it:

```bash
supabase db push
```

Or paste it into Dashboard > **Database > SQL Editor** and click Run (once).

---

## 4. Native deep links (iOS + Android)

On email signup the user opens a link in their phone's browser. Without a deep link, the browser loads a Supabase page and stops. With a deep link configured, the OS hands the URL back to the BarkDate app and `supabase_flutter` picks up the session.

We'll use `io.supabase.bark://login-callback/` (already the scheme Google OAuth uses - see `sign_up_screen.dart` L82).

### iOS - `ios/Runner/Info.plist`

Add inside `<dict>` (near other `CFBundleURLTypes` if any):

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLName</key>
        <string>io.supabase.bark</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>io.supabase.bark</string>
        </array>
    </dict>
</array>
```

Check if it's already there - `grep -n CFBundleURLTypes ios/Runner/Info.plist`. If it is, just add the `io.supabase.bark` scheme inside the existing array instead of duplicating the key.

### Android - `android/app/src/main/AndroidManifest.xml`

Inside the `<activity android:name=".MainActivity" ...>` tag, add a new `<intent-filter>`:

```xml
<intent-filter android:autoVerify="false">
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    <data android:scheme="io.supabase.bark" android:host="login-callback" />
</intent-filter>
```

### Add the scheme to Supabase's redirect allowlist

Back in section 1, make sure `io.supabase.bark://login-callback/` is on the Redirect URLs list. It won't work otherwise - Supabase will reject the redirect.

> Web builds don't need this section. Sections 1 and 2 are enough for web.

---

## 5. OPTIONAL - Customize the confirmation email template

Dashboard > **Authentication > Email Templates > Confirm signup**.

The default template already contains `{{ .ConfirmationURL }}` which respects Site URL + Redirect URLs. Edit the copy if you want it to say "Welcome to BarkDate" instead of "Confirm your signup".

You don't need to change anything here for the flow to work.

---

## 6. Verify everything is wired up

Once Sprints 2 and 3 are done, walk through this checklist:

1. In the Dashboard > **Auth Users**, delete your test account so it's a fresh state.
2. Run the Flutter app. Navigate to Sign Up, fill in name + email + password, submit.
3. You should land on the **Verify email** screen (added in Sprint 2).
4. Check your inbox. The email should come from `no-reply@...supabase.co` (or your SMTP config).
5. Tap the link:
   - **Web dev**: opens `http://localhost:50342/...`. The Flutter app running there should flip to signed-in and land on the onboarding **Location Permissions** screen.
   - **Native**: the OS should open BarkDate directly (thanks to section 4). Same Location Permissions screen.
6. Continue through Location -> FastTrack dog setup -> Home.

If any step fails, the doc section at fault is written in the error (e.g. "redirect URL not allowed" -> section 1).

---

## 7. Common pitfalls

- **"localhost port changed"**: Flutter web picks a random port each `flutter run`. Either always run with `flutter run -d chrome --web-port=50342`, or add multiple ports to Redirect URLs.
- **"I clicked the email link but nothing happens"**: Site URL is missing or doesn't match your dev URL. Check section 1.
- **"Signed in but verify screen still shows"**: `auth.users.email_confirmed_at` might be set but the verify screen's "I've verified" button wasn't tapped. Either tap it (Sprint 2c auto-routes through `SplashRoute`) or confirm the deep link fires `onAuthStateChange`.
- **"I pushed config.toml but Dashboard still shows old values"**: `supabase config push` requires that the CLI is linked to the remote project. Re-run `supabase link --project-ref caottaawpnocywayjmyl`.
- **"`supabase db push` fails with 'migrations out of order'"**: you have pending remote migrations. Run `supabase db pull` first to sync, then push.

---

## 8. CLI quick reference

```bash
# who am I + am I linked?
supabase projects list

# sync remote schema into local migrations folder (safe; read-only on remote)
supabase db pull

# push local migrations + config.toml to remote
supabase db push
supabase config push

# open Dashboard directly
open "https://supabase.com/dashboard/project/caottaawpnocywayjmyl"

# tail auth logs while testing signup
supabase logs auth --linked --project-ref caottaawpnocywayjmyl
```

If `supabase` itself fails, these are the usual suspects:

- Docker Desktop not running (only needed for `supabase start` / `supabase db reset` with the LOCAL stack - remote ops like `config push` don't need it).
- Not logged in: `supabase login` and paste the access token from <https://supabase.com/dashboard/account/tokens>.
- Not linked: `supabase link --project-ref caottaawpnocywayjmyl`.
