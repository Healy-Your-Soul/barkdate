# 🔧 Supabase Setup Instructions

## 🚨 **Critical Issue Found:**
Your app has a **database foreign key constraint** that's preventing user signup and email sending.

## 📝 **Quick Fix Steps:**

### 1. **Disable Email Confirmation (Temporary)**
1. Go to your Supabase Dashboard: `https://caottaawpnocywayjmyl.supabase.co`
2. Go to **Authentication** → **Settings** 
3. **TURN OFF** "Enable email confirmations" (temporarily)
4. Click **Save**

This will allow users to sign up immediately without email verification.

### 2. **Fix Database Trigger** 
Run this SQL in your **Supabase SQL Editor**:

```sql
-- Function to handle new user creation (improved with error handling)
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.users (id, email, name, created_at, updated_at)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'name', 'User'),
    NOW(),
    NOW()
  );
  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  -- Log error but don't fail the auth process
  RAISE LOG 'Error creating user profile for %: %', NEW.id, SQLERRM;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger to call the function when a new user signs up
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
```

### 3. **Test the App**
1. Try signing up with a new email
2. You should go directly to the main app (no email verification needed)
3. Create your profile and test photo uploads

### 4. **Re-enable Email Confirmation (Later)**
Once everything works:
1. Go back to **Authentication** → **Settings**
2. **TURN ON** "Enable email confirmations" 
3. Configure email templates if needed

## 🔍 **What Was Wrong:**

The error `"users_id_fkey" violates foreign key constraint` means:
- Your `users` table requires the user to exist in `auth.users` first
- But our app was trying to create the user profile **immediately** after signup
- This caused a timing conflict that prevented signup from completing
- No user = no verification email sent

## 🎯 **The Fix:**

1. **Database trigger** automatically creates user profiles **after** auth.users is populated
2. **Removed manual user creation** from the app code  
3. **Simplified signup flow** to avoid timing conflicts

Try these steps and let me know if signup works! 🚀
