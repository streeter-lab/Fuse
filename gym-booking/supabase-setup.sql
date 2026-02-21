-- ============================================================
-- FUSE Fitness - Supabase SQL Setup
-- Run this entire script in the Supabase SQL Editor.
-- ============================================================
--
-- IMPORTANT: Disable email verification in Supabase Dashboard:
--   Authentication > Providers > Email > Turn OFF "Confirm email"
-- ============================================================

-- 1. TABLES
-- ----------------------------------------------------------

-- Profiles table: extends Supabase auth.users
create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null,
  phone text,
  membership_type text not null default 'standard'
    check (membership_type in ('standard', 'premium')),
  is_admin boolean not null default false,
  created_at timestamptz not null default now()
);

-- Classes table: gym classes and sessions
create table public.classes (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  instructor text not null,
  description text,
  start_time timestamptz not null,
  end_time timestamptz not null,
  capacity integer not null check (capacity > 0),
  location text not null,
  is_cancelled boolean not null default false,
  created_at timestamptz not null default now()
);

-- Bookings table: member bookings for classes
create table public.bookings (
  id uuid primary key default gen_random_uuid(),
  class_id uuid not null references public.classes(id) on delete cascade,
  member_id uuid not null references public.profiles(id) on delete cascade,
  status text not null default 'confirmed'
    check (status in ('confirmed', 'waitlist', 'cancelled')),
  booked_at timestamptz not null default now()
);

-- 2. INDEXES
-- ----------------------------------------------------------

create index idx_bookings_class_id on public.bookings(class_id);
create index idx_bookings_member_id on public.bookings(member_id);

-- 3. ENABLE ROW LEVEL SECURITY
-- ----------------------------------------------------------

alter table public.profiles enable row level security;
alter table public.classes enable row level security;
alter table public.bookings enable row level security;

-- 4. HELPER FUNCTION (bypasses RLS to avoid recursion)
-- ----------------------------------------------------------

create or replace function public.is_admin()
returns boolean
language sql
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and is_admin = true
  );
$$;

-- 5. RLS POLICIES
-- ----------------------------------------------------------

-- Profiles: users can read their own row
create policy "Users can view own profile"
  on public.profiles for select
  using (auth.uid() = id);

-- Profiles: users can update their own row (but not privileged columns)
create policy "Users can update own profile"
  on public.profiles for update
  using (auth.uid() = id)
  with check (
    is_admin = (select p.is_admin from public.profiles p where p.id = auth.uid())
    and membership_type = (select p.membership_type from public.profiles p where p.id = auth.uid())
  );

-- Profiles: allow inserts from the trigger (service role) and the user themselves
create policy "Users can insert own profile"
  on public.profiles for insert
  with check (auth.uid() = id);

-- Profiles: admins can read all profiles (needed for admin panel)
create policy "Admins can view all profiles"
  on public.profiles for select
  using ( public.is_admin() );

-- Classes: anyone authenticated or anonymous can read
create policy "Anyone can view classes"
  on public.classes for select
  using (true);

-- Classes: only admins can insert
create policy "Admins can insert classes"
  on public.classes for insert
  with check ( public.is_admin() );

-- Classes: only admins can update
create policy "Admins can update classes"
  on public.classes for update
  using ( public.is_admin() );

-- Bookings: users can view their own bookings
create policy "Users can view own bookings"
  on public.bookings for select
  using (auth.uid() = member_id);

-- Bookings: admins can view all bookings
create policy "Admins can view all bookings"
  on public.bookings for select
  using ( public.is_admin() );

-- Bookings: users can insert their own bookings
create policy "Users can insert own bookings"
  on public.bookings for insert
  with check (auth.uid() = member_id);

-- Bookings: users can update their own bookings (for cancellation)
create policy "Users can update own bookings"
  on public.bookings for update
  using (auth.uid() = member_id);

-- Bookings: admins can update any booking
create policy "Admins can update any booking"
  on public.bookings for update
  using ( public.is_admin() );

-- 6. TRIGGER: auto-create profile on user signup
-- ----------------------------------------------------------

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = ''
as $$
begin
  insert into public.profiles (id, full_name, phone)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'full_name', ''),
    coalesce(new.raw_user_meta_data ->> 'phone', '')
  );
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- 7. UNIQUE CONSTRAINT: prevent duplicate active bookings
-- ----------------------------------------------------------

create unique index idx_bookings_unique_active
  on public.bookings (class_id, member_id)
  where status in ('confirmed', 'waitlist');

-- 8. SERVER-SIDE FUNCTIONS (bypass RLS for accurate counts & atomic operations)
-- ----------------------------------------------------------

-- Get booking counts for a set of classes (bypasses RLS so all bookings are counted)
create or replace function public.get_booking_counts(p_class_ids uuid[])
returns table(class_id uuid, confirmed_count bigint, waitlist_count bigint)
language sql
security definer
set search_path = ''
as $$
  select
    b.class_id,
    count(*) filter (where b.status = 'confirmed') as confirmed_count,
    count(*) filter (where b.status = 'waitlist') as waitlist_count
  from public.bookings b
  where b.class_id = any(p_class_ids)
    and b.status in ('confirmed', 'waitlist')
  group by b.class_id;
$$;

-- Book a class atomically (prevents TOCTOU race condition and enforces capacity)
create or replace function public.book_class(p_class_id uuid, p_member_id uuid)
returns json
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_class public.classes;
  v_confirmed_count integer;
  v_status text;
  v_booking public.bookings;
begin
  -- Verify the caller is booking for themselves
  if p_member_id != auth.uid() then
    raise exception 'You can only book classes for yourself.';
  end if;

  -- Lock the class row to prevent concurrent bookings from racing
  select * into v_class from public.classes where id = p_class_id for update;

  if v_class is null then
    raise exception 'Class not found.';
  end if;

  if v_class.is_cancelled then
    raise exception 'This class has been cancelled.';
  end if;

  -- Check for existing active booking
  if exists (
    select 1 from public.bookings
    where class_id = p_class_id and member_id = p_member_id
      and status in ('confirmed', 'waitlist')
  ) then
    raise exception 'You already have an active booking for this class.';
  end if;

  -- Count confirmed bookings while holding the lock
  select count(*) into v_confirmed_count
  from public.bookings
  where class_id = p_class_id and status = 'confirmed';

  -- Determine status based on remaining capacity
  v_status := case when v_confirmed_count < v_class.capacity then 'confirmed' else 'waitlist' end;

  -- Insert the booking
  insert into public.bookings (class_id, member_id, status)
  values (p_class_id, p_member_id, v_status)
  returning * into v_booking;

  return row_to_json(v_booking);
end;
$$;

-- Cancel a booking and promote from waitlist atomically
create or replace function public.cancel_and_promote(p_booking_id uuid, p_member_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_booking public.bookings;
  v_next_id uuid;
begin
  -- Verify the caller is cancelling their own booking
  if p_member_id != auth.uid() then
    raise exception 'You can only cancel your own bookings.';
  end if;

  -- Fetch and verify the booking belongs to the user (lock row to prevent double-cancel race)
  select * into v_booking from public.bookings
  where id = p_booking_id and member_id = p_member_id
  for update;

  if v_booking is null then
    raise exception 'Booking not found.';
  end if;

  if v_booking.status = 'cancelled' then
    raise exception 'Booking is already cancelled.';
  end if;

  -- Cancel the booking
  update public.bookings set status = 'cancelled' where id = p_booking_id;

  -- If the cancelled booking was confirmed, promote the earliest waitlisted booking
  if v_booking.status = 'confirmed' then
    select id into v_next_id
    from public.bookings
    where class_id = v_booking.class_id and status = 'waitlist'
    order by booked_at asc
    limit 1
    for update;

    if v_next_id is not null then
      update public.bookings set status = 'confirmed' where id = v_next_id;
    end if;
  end if;
end;
$$;

-- Get waitlist position for a member in a class (bypasses RLS for accurate position)
create or replace function public.get_waitlist_position(p_class_id uuid, p_member_id uuid)
returns integer
language sql
security definer
set search_path = ''
as $$
  select coalesce(
    (select pos::integer
     from (
       select member_id, row_number() over (order by booked_at asc) as pos
       from public.bookings
       where class_id = p_class_id and status = 'waitlist'
     ) ranked
     where member_id = p_member_id),
    0
  );
$$;
