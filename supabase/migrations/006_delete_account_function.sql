-- ============================================================================
-- ACCOUNT DELETION LOGIC
-- ============================================================================

-- 1. Create a function that can be called via RPC to delete the current user's account
CREATE OR REPLACE FUNCTION delete_account()
RETURNS VOID AS $$
DECLARE
  current_user_id UUID;
BEGIN
  current_user_id := auth.uid();
  
  IF current_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- Delete from public.vendors
  -- This requires the user to have DELETE permission on their own record (which they should via RLS)
  DELETE FROM public.vendors WHERE id = current_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- 2. Create a trigger function to delete the auth user when the public vendor record is deleted
-- This ensures that when the vendor data is gone, the login is also removed.
CREATE OR REPLACE FUNCTION delete_auth_user_on_vendor_delete()
RETURNS TRIGGER AS $$
BEGIN
  -- Delete the user from auth.users
  -- This requires SECURITY DEFINER on this function and the postgres role (or a role with superuser/admin privileges)
  DELETE FROM auth.users WHERE id = OLD.id;
  RETURN OLD;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Attach the trigger to the vendors table
DROP TRIGGER IF EXISTS on_vendor_delete_remove_auth_user ON public.vendors;

CREATE TRIGGER on_vendor_delete_remove_auth_user
  AFTER DELETE ON public.vendors
  FOR EACH ROW
  EXECUTE FUNCTION delete_auth_user_on_vendor_delete();
