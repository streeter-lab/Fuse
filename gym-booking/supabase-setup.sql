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

-- Profiles: users can update their own row
create policy "Users can update own profile"
  on public.profiles for update
  using (auth.uid() = id);

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
