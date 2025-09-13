# 🔧 BarkDate Authentication Setup Guide

## 🎯 Two-Step Fix Process

### **Step 1: Fix Foreign Key Constraint (CRITICAL)**

1. **Open your Supabase Dashboard**: https://supabase.com/dashboard/project/caottaawpnocywayjmyl
2. **Go to SQL Editor**
3. **Copy and run this analysis query first**:

```sql
-- Check the foreign key constraint causing issues
SELECT
    tc.constraint_name,
    tc.table_name, 
    kcu.column_name, 
    ccu.table_name AS foreign_table_name,
    ccu.column_name AS foreign_column_name
FROM 
    information_schema.table_constraints AS tc 
    JOIN information_schema.key_column_usage AS kcu
      ON tc.constraint_name = kcu.constraint_name
    JOIN information_schema.constraint_column_usage AS ccu
      ON ccu.constraint_name = tc.constraint_name
WHERE tc.constraint_type = 'FOREIGN KEY' 
    AND tc.table_name='users'
    AND tc.table_schema = 'public';
```

4. **Then run the fix function**:

```sql
-- Create the safe user sync function
CREATE OR REPLACE FUNCTION sync_firebase_user_safe(
    user_email text,
    user_name text DEFAULT NULL,
    avatar_url text DEFAULT NULL,
    firebase_uid text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    user_id uuid;
    auth_user_exists boolean;
BEGIN
    -- Check if user already exists by email
    SELECT id INTO user_id 
    FROM public.users 
    WHERE email = user_email;
    
    IF user_id IS NOT NULL THEN
        RETURN user_id;
    END IF;
    
    -- Check if auth user exists
    SELECT EXISTS(
        SELECT 1 FROM auth.users WHERE email = user_email
    ) INTO auth_user_exists;
    
    IF NOT auth_user_exists THEN
        RAISE EXCEPTION 'Auth user with email % does not exist', user_email;
    END IF;
    
    -- Get auth user ID and create public user
    SELECT id INTO user_id FROM auth.users WHERE email = user_email;
    
    INSERT INTO public.users (
        id, email, name, avatar_url, firebase_uid, created_at, updated_at
    ) VALUES (
        user_id, user_email, 
        COALESCE(user_name, split_part(user_email, '@', 1)),
        avatar_url, firebase_uid, NOW(), NOW()
    )
    ON CONFLICT (email) DO UPDATE SET
        name = COALESCE(EXCLUDED.name, public.users.name),
        avatar_url = COALESCE(EXCLUDED.avatar_url, public.users.avatar_url),
        firebase_uid = COALESCE(EXCLUDED.firebase_uid, public.users.firebase_uid),
        updated_at = NOW()
    RETURNING id INTO user_id;
    
    RETURN user_id;
END;
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION sync_firebase_user_safe TO authenticated;
```

### **Step 2: Complete Google OAuth Setup**

Following the [Supabase Google OAuth Guide](https://supabase.com/docs/guides/auth/social-login/auth-google):

#### **A. Google Cloud Console Setup**
1. **Go to**: https://console.cloud.google.com/
2. **Select your project**: `co1l0uvij8nhdcps5tiyii9b2wp9hp`
3. **Navigate to**: APIs & Services → Credentials
4. **Find your OAuth 2.0 Client ID**
5. **Add these redirect URIs**:
   ```
   https://caottaawpnocywayjmyl.supabase.co/auth/v1/callback
   http://localhost:3000 (for local testing)
   ```

#### **B. Supabase Configuration**
1. **Open**: https://supabase.com/dashboard/project/caottaawpnocywayjmyl/auth/providers
2. **Enable Google Provider**
3. **Add your credentials**:
   - **Client ID**: `[Your Google OAuth Client ID]`
   - **Client Secret**: `[Your Google OAuth Client Secret]`

#### **C. Flutter Configuration**
Your `firebase_options.dart` should already have:
```dart
iosBundleId: 'com.example.barkdate',
```

#### **D. Web Configuration**
Your `web/index.html` should have the meta tag (already added):
```html
<meta name="google-signin-client_id" content="YOUR_GOOGLE_CLIENT_ID">
```

## 🧪 **Step 3: Test the Complete Flow**

1. **Run your Flutter app**:
   ```bash
   flutter run -d chrome --web-port 3000
   ```

2. **Test the authentication**:
   - Click the debug button: "🔧 Debug: Test Auth Sync"
   - Try both email/password and Google sign-in
   - Verify the user sync works without foreign key errors

## 🚨 **Common Issues & Solutions**

### **Foreign Key Constraint Error**
```
insert or update on table "users" violates foreign key constraint "users_id_fkey"
```
**Solution**: Run the SQL queries above in Supabase SQL Editor

### **Google Sign-In Client ID Missing**
```
PlatformException(sign_in_failed, ...)
```
**Solution**: Ensure the meta tag in `web/index.html` has your actual client ID

### **Redirect URI Mismatch**
```
Error 400: redirect_uri_mismatch
```
**Solution**: Add all your domains to Google OAuth redirect URIs

## 🎉 **Expected Result**

After completing these steps:
- ✅ **Firebase authentication** works with email/password and Google
- ✅ **Supabase sync** completes without foreign key errors  
- ✅ **User flow** proceeds: auth → profile → dog profile → main app
- ✅ **Seamless experience** for both sign-up and sign-in users

## 📋 **Quick Checklist**

- [ ] SQL queries run successfully in Supabase
- [ ] Google OAuth configured in Google Cloud Console
- [ ] Google provider enabled in Supabase Auth
- [ ] Client ID added to Flutter web/index.html
- [ ] Redirect URIs configured correctly
- [ ] App tested with debug widget
