-- ===================================================================
-- FIX USERS FOREIGN KEY CONSTRAINT FOR FIREBASE-SUPABASE SYNC
-- ===================================================================
-- Migration to resolve users_id_fkey violation error
-- and enable seamless Firebase-to-Supabase user synchronization

-- ===================================================================
-- 1. ANALYZE CURRENT CONSTRAINT (for debugging)
-- ===================================================================

-- Check the current foreign key constraint causing issues
DO $$
DECLARE
    constraint_exists boolean;
BEGIN
    SELECT EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE constraint_type = 'FOREIGN KEY' 
        AND table_name = 'users'
        AND table_schema = 'public'
        AND constraint_name LIKE '%_id_fkey%'
    ) INTO constraint_exists;
    
    IF constraint_exists THEN
        RAISE NOTICE 'Foreign key constraint found on users table';
    ELSE
        RAISE NOTICE 'No problematic foreign key constraint found';
    END IF;
END $$;

-- ===================================================================
-- 2. CREATE SAFE USER SYNC FUNCTION
-- ===================================================================

-- Function to safely sync Firebase users with Supabase
-- This handles the foreign key constraint by ensuring proper order
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
    -- Check if we already have this user in public.users by email
    SELECT id INTO user_id 
    FROM public.users 
    WHERE email = user_email;
    
    IF user_id IS NOT NULL THEN
        -- User already exists, update and return their ID
        UPDATE public.users 
        SET 
            name = COALESCE(user_name, public.users.name),
            avatar_url = COALESCE(sync_firebase_user_safe.avatar_url, public.users.avatar_url),
            firebase_uid = COALESCE(sync_firebase_user_safe.firebase_uid, public.users.firebase_uid),
            updated_at = NOW()
        WHERE email = user_email
        RETURNING id INTO user_id;
        
        RETURN user_id;
    END IF;
    
    -- Check if auth user exists for this email
    SELECT EXISTS(
        SELECT 1 FROM auth.users WHERE email = user_email
    ) INTO auth_user_exists;
    
    IF NOT auth_user_exists THEN
        -- Auth user doesn't exist, we can't create public user yet
        RAISE EXCEPTION 'Auth user with email % does not exist. Create auth user first.', user_email;
    END IF;
    
    -- Get the auth user ID
    SELECT id INTO user_id 
    FROM auth.users 
    WHERE email = user_email;
    
    -- Create the public user record using the auth user's ID
    INSERT INTO public.users (
        id, 
        email, 
        name, 
        avatar_url, 
        firebase_uid,
        created_at,
        updated_at
    ) VALUES (
        user_id,
        user_email,
        COALESCE(user_name, split_part(user_email, '@', 1)),
        avatar_url,
        firebase_uid,
        NOW(),
        NOW()
    )
    ON CONFLICT (email) DO UPDATE SET
        name = COALESCE(EXCLUDED.name, public.users.name),
        avatar_url = COALESCE(EXCLUDED.avatar_url, public.users.avatar_url),
        firebase_uid = COALESCE(EXCLUDED.firebase_uid, public.users.firebase_uid),
        updated_at = NOW()
    RETURNING id INTO user_id;
    
    RETURN user_id;
EXCEPTION
    WHEN foreign_key_violation THEN
        RAISE EXCEPTION 'Foreign key constraint violation: Auth user with email % must exist first', user_email;
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Error syncing user %: %', user_email, SQLERRM;
END;
$$;

-- ===================================================================
-- 3. GRANT PERMISSIONS
-- ===================================================================

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION sync_firebase_user_safe TO authenticated;
GRANT EXECUTE ON FUNCTION sync_firebase_user_safe TO anon;

-- ===================================================================
-- 4. CREATE HELPER FUNCTION FOR FIREBASE AUTH USER CREATION
-- ===================================================================

-- Function to create a shadow auth user for Firebase users
-- This satisfies the foreign key constraint
CREATE OR REPLACE FUNCTION create_auth_user_for_firebase(
    user_email text,
    user_name text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    new_user_id uuid;
BEGIN
    -- Generate a UUID for the new user
    new_user_id := gen_random_uuid();
    
    -- Insert into auth.users (this is typically handled by Supabase Auth)
    -- Note: This is a simplified version - in production, Supabase handles this
    INSERT INTO auth.users (
        id,
        email,
        encrypted_password,
        email_confirmed_at,
        created_at,
        updated_at,
        raw_user_meta_data
    ) VALUES (
        new_user_id,
        user_email,
        crypt('firebase_shadow_user', gen_salt('bf')), -- Dummy password
        NOW(), -- Assume confirmed since it comes from Firebase
        NOW(),
        NOW(),
        jsonb_build_object(
            'display_name', COALESCE(user_name, split_part(user_email, '@', 1)),
            'firebase_sync', true
        )
    )
    ON CONFLICT (email) DO UPDATE SET
        updated_at = NOW(),
        raw_user_meta_data = COALESCE(
            auth.users.raw_user_meta_data || EXCLUDED.raw_user_meta_data,
            EXCLUDED.raw_user_meta_data
        )
    RETURNING id INTO new_user_id;
    
    RETURN new_user_id;
EXCEPTION
    WHEN OTHERS THEN
        -- If we can't create auth user, return existing one
        SELECT id INTO new_user_id FROM auth.users WHERE email = user_email;
        IF new_user_id IS NOT NULL THEN
            RETURN new_user_id;
        END IF;
        RAISE EXCEPTION 'Could not create or find auth user for %: %', user_email, SQLERRM;
END;
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION create_auth_user_for_firebase TO authenticated;
GRANT EXECUTE ON FUNCTION create_auth_user_for_firebase TO anon;

-- ===================================================================
-- 5. VERIFICATION
-- ===================================================================

-- Log successful migration
SELECT 'Migration completed successfully! ✅' as status;
SELECT 'Created function: sync_firebase_user_safe()' as created;
SELECT 'Created function: create_auth_user_for_firebase()' as also_created;
