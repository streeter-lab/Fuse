-- fix-upcoming-bookings.sql
-- Adds a server-side RPC function to efficiently fetch a member's upcoming bookings.
--
-- The previous client-side approach used a foreign-table filter (.gte('classes.start_time', now))
-- which PostgREST does not push down as a WHERE clause on the bookings table. Instead it
-- returns ALL bookings and nullifies the joined class where the condition fails, requiring
-- client-side filtering and transferring unnecessary data.
--
-- This function performs a proper JOIN with a WHERE clause so only upcoming bookings are
-- returned from the database.
--
-- Safe to re-run: uses CREATE OR REPLACE.

CREATE OR REPLACE FUNCTION get_upcoming_bookings(p_member_id uuid)
RETURNS TABLE (
  id uuid,
  status text,
  booked_at timestamptz,
  class_id uuid,
  class_title text,
  class_instructor text,
  class_start_time timestamptz,
  class_end_time timestamptz,
  class_location text,
  class_is_cancelled boolean
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    b.id,
    b.status::text,
    b.booked_at,
    c.id        AS class_id,
    c.title     AS class_title,
    c.instructor AS class_instructor,
    c.start_time AS class_start_time,
    c.end_time   AS class_end_time,
    c.location   AS class_location,
    c.is_cancelled AS class_is_cancelled
  FROM bookings b
  JOIN classes c ON c.id = b.class_id
  WHERE b.member_id = p_member_id
    AND b.status IN ('confirmed', 'waitlist')
    AND c.start_time >= now()
  ORDER BY c.start_time ASC;
$$;
