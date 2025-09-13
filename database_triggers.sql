-- Database Triggers for BarkDate
-- Automatically create user profile when auth.users record is created

-- Function to handle new user creation
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

-- Function to handle user deletion and cleanup
CREATE OR REPLACE FUNCTION public.handle_user_deletion()
RETURNS TRIGGER AS $$
BEGIN
  -- This function will be called when a user is deleted
  -- The CASCADE constraints will handle all database cleanup automatically
  
  -- Log the deletion for audit purposes
  RAISE LOG 'User % deleted - all related data will be automatically removed via CASCADE constraints', OLD.id;
  
  -- Note: Supabase storage cleanup should be handled by your application
  -- or by a separate storage policy/function
  
  RETURN OLD;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger to call the function when a user is deleted
DROP TRIGGER IF EXISTS on_auth_user_deleted ON auth.users;
CREATE TRIGGER on_auth_user_deleted
  BEFORE DELETE ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_user_deletion();

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
