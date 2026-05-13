# BarkDate Update Management Guide 🚀

This guide explains how to manage application updates for BarkDate using the dual-layer update system: **Shorebird** for silent patches and **Supabase** for required major updates.

---

## 1. Shorebird (Silent OTA Patches)
Use Shorebird when you have bug fixes, UI tweaks, or minor feature additions that **do not** involve new native dependencies or changes to `ios/` or `android/` folders.

### Step 1: Initialize Shorebird (One-time)
If you haven't already, link your machine to the Shorebird project:
```bash
shorebird init
```

### Step 2: Push a Patch
After making your Dart code changes:
```bash
# Push to Android
shorebird patch android

# Push to iOS
shorebird patch ios
```
*   **What happens?** Users will download this in the background the next time they open the app. The update will apply automatically on their next restart.

---

## 2. Supabase (Major / Required Updates)
Use this system when you have made major changes, added new native plugins (like a new Google Maps version), or want to force users to move to a new version.

### How to Trigger a Blocking Update
1.  Go to your **Supabase Dashboard**.
2.  Open the `app_config` table.
3.  Locate the row with `key = 'update_config'`.
4.  Update the `value` JSON:
    *   `latest_version`: Set to your new version (e.g., `"1.1.0"`).
    *   `min_required_version`: Set this to the version you want to force users to. If a user's app version is lower than this, they will be **blocked** by the "Update Required" screen.
    *   `android_url` / `ios_url`: Update these to point to the new store links or direct download pages.
    *   `message`: Customize the text shown to the user.

### Example JSON:
```json
{
  "latest_version": "1.2.0",
  "min_required_version": "1.1.0",
  "android_url": "https://play.google.com/store/apps/details?id=com.barkdate.app",
  "ios_url": "https://apps.apple.com/app/barkdate/id123456789",
  "message": "We've added incredible new social features! Please update to continue your adventure."
}
```

---

## 3. Full Deployment Workflow
When you are ready for a major release, follow this sequence:

1.  **Build Release**: Create your base releases for the stores:
    ```bash
    shorebird release android
    shorebird release ios
    ```
2.  **Submit to Stores**: Upload the generated `.aab` (Android) and `.ipa` (iOS) to Google Play Console and App Store Connect.
3.  **Update Supabase**: Once the stores have approved your app, update the `app_config` table in Supabase so existing users are notified or forced to update.
4.  **Patch if needed**: If you find a small bug 10 minutes after release, don't resubmit to the stores! Just use `shorebird patch`.

---

## 💡 Best Practices
*   **Version Format**: Always use semantic versioning (`x.y.z`) in both `pubspec.yaml` and Supabase.
*   **Testing Patches**: You can use `shorebird preview` to test a patch on a device before sending it to everyone.
*   **Safety First**: Only increase `min_required_version` when absolutely necessary, as it prevents users from using the app until they download the new version.
