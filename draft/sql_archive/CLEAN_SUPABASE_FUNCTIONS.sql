-- Clean SQL functions for Supabase (copy each function separately)

-- FUNCTION 1: Storage cleanup (copy this first)
CREATE OR REPLACE FUNCTION public.cleanup_user_storage(user_id uuid)
RETURNS void AS $$
BEGIN
  RAISE LOG 'Cleaning up storage files for user %', user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- FUNCTION 2: User account deletion (copy this second)
CREATE OR REPLACE FUNCTION public.delete_user_account(user_id uuid)
RETURNS void AS $$
BEGIN
  RAISE LOG 'Deleting user account %', user_id;
  DELETE FROM auth.users WHERE id = user_id;
  RAISE LOG 'User account % successfully deleted', user_id;
EXCEPTION WHEN OTHERS THEN
  RAISE LOG 'Error deleting user account %: %', user_id, SQLERRM;
  RAISE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
