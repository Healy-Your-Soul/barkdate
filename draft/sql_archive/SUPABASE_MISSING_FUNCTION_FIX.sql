-- Missing functions fix for BarkDate account deletion
-- Run this in your Supabase SQL Editor

-- Function to clean up user's storage files
-- This should be called from your application before deleting the user
CREATE OR REPLACE FUNCTION public.cleanup_user_storage(user_id uuid)
RETURNS void AS $$
BEGIN
  -- Log the storage cleanup attempt
  RAISE LOG 'Cleaning up storage files for user %', user_id;
  
  -- Note: This function logs the cleanup but actual file deletion
  -- should be handled by your application using Supabase Storage API
  -- or by a separate background job
  
  -- You can add additional cleanup logic here if needed
  
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to delete user account completely
-- This handles both database and auth deletion
CREATE OR REPLACE FUNCTION public.delete_user_account(user_id uuid)
RETURNS void AS $$
BEGIN
  -- Log the deletion attempt
  RAISE LOG 'Deleting user account %', user_id;
  
  -- Delete from auth.users (this will trigger CASCADE deletes)
  -- Note: This requires service_role access or RLS policy
  DELETE FROM auth.users WHERE id = user_id;
  
  -- Log completion
  RAISE LOG 'User account % successfully deleted', user_id;
  
EXCEPTION WHEN OTHERS THEN
  -- Log error and re-raise
  RAISE LOG 'Error deleting user account %: %', user_id, SQLERRM;
  RAISE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
