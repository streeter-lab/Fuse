-- ============================================================
-- FUSE Fitness - Onboarding & Member Management Migration
-- Safe to re-run: uses IF NOT EXISTS, CREATE OR REPLACE, DROP IF EXISTS
-- ============================================================

-- 1. NEW COLUMNS ON PROFILES
-- ----------------------------------------------------------

ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS emergency_contact_name text;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS emergency_contact_phone text;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS medical_notes text;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS terms_accepted_at timestamptz;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS onboarding_complete boolean NOT NULL DEFAULT false;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS is_active boolean NOT NULL DEFAULT true;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS email text;

-- 2. UPDATE TRIGGER: handle_new_user()
-- ----------------------------------------------------------
-- Now also inserts emergency contact, medical notes, terms, onboarding status, and email.

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = ''
AS $$
BEGIN
  INSERT INTO public.profiles (
    id, full_name, phone, email,
    emergency_contact_name, emergency_contact_phone, medical_notes,
    terms_accepted_at, onboarding_complete
  )
  VALUES (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'full_name', ''),
    coalesce(new.raw_user_meta_data ->> 'phone', ''),
    new.email,
    new.raw_user_meta_data ->> 'emergency_contact_name',
    new.raw_user_meta_data ->> 'emergency_contact_phone',
    new.raw_user_meta_data ->> 'medical_notes',
    CASE WHEN (new.raw_user_meta_data ->> 'terms_accepted') = 'true' THEN now() ELSE NULL END,
    CASE WHEN (new.raw_user_meta_data ->> 'terms_accepted') = 'true' THEN true ELSE false END
  );
  RETURN new;
END;
$$;

-- 3. BACKFILL EMAIL FOR EXISTING USERS
-- ----------------------------------------------------------

UPDATE public.profiles p
SET email = u.email
FROM auth.users u
WHERE u.id = p.id AND p.email IS NULL;

-- 4. RLS POLICY: Admins can update any profile
-- ----------------------------------------------------------

DROP POLICY IF EXISTS "Admins can update any profile" ON public.profiles;
CREATE POLICY "Admins can update any profile"
  ON public.profiles FOR UPDATE
  USING ( public.is_admin() );

-- 5. UPDATE book_class() WITH MEMBERSHIP BOOKING WINDOW
-- ----------------------------------------------------------

CREATE OR REPLACE FUNCTION public.book_class(p_class_id uuid, p_member_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_class public.classes;
  v_confirmed_count integer;
  v_status text;
  v_booking public.bookings;
  v_membership text;
  v_max_days integer;
BEGIN
  -- Verify the caller is booking for themselves
  IF p_member_id != auth.uid() THEN
    RAISE EXCEPTION 'You can only book classes for yourself.';
  END IF;

  -- Lock the class row to prevent concurrent bookings from racing
  SELECT * INTO v_class FROM public.classes WHERE id = p_class_id FOR UPDATE;

  IF v_class IS NULL THEN
    RAISE EXCEPTION 'Class not found.';
  END IF;

  IF v_class.is_cancelled THEN
    RAISE EXCEPTION 'This class has been cancelled.';
  END IF;

  -- Check membership booking window
  SELECT membership_type INTO v_membership FROM public.profiles WHERE id = p_member_id;
  v_max_days := CASE WHEN v_membership = 'premium' THEN 14 ELSE 7 END;

  IF v_class.start_time > (now() + (v_max_days || ' days')::interval) THEN
    RAISE EXCEPTION 'This class is not yet available for booking. Premium members can book up to 14 days ahead.';
  END IF;

  -- Check for existing active booking
  IF EXISTS (
    SELECT 1 FROM public.bookings
    WHERE class_id = p_class_id AND member_id = p_member_id
      AND status IN ('confirmed', 'waitlist')
  ) THEN
    RAISE EXCEPTION 'You already have an active booking for this class.';
  END IF;

  -- Count confirmed bookings while holding the lock
  SELECT count(*) INTO v_confirmed_count
  FROM public.bookings
  WHERE class_id = p_class_id AND status = 'confirmed';

  -- Determine status based on remaining capacity
  v_status := CASE WHEN v_confirmed_count < v_class.capacity THEN 'confirmed' ELSE 'waitlist' END;

  -- Insert the booking
  INSERT INTO public.bookings (class_id, member_id, status)
  VALUES (p_class_id, p_member_id, v_status)
  RETURNING * INTO v_booking;

  RETURN row_to_json(v_booking);
END;
$$;

-- 6. ADMIN CREATE MEMBER PLACEHOLDER
-- ----------------------------------------------------------
-- NOTE: Actual user creation requires a Supabase Edge Function with service_role key.
-- This RPC serves as a placeholder and documents the intended interface.

CREATE OR REPLACE FUNCTION public.admin_create_member(
  p_email text,
  p_password text,
  p_full_name text,
  p_phone text,
  p_membership_type text DEFAULT 'standard'
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = ''
AS $$
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Only admins can create members.';
  END IF;

  -- Creating auth users requires the service_role key which must NEVER be exposed client-side.
  -- Use the Supabase Edge Function at supabase/functions/create-member/index.ts instead.
  RAISE EXCEPTION 'Admin user creation requires a Supabase Edge Function with service_role key. Deploy supabase/functions/create-member/ first.';
END;
$$;
