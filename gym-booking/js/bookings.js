// bookings.js - Booking, cancellation, and waitlist logic.
// Uses server-side RPC functions to bypass RLS for accurate counts
// and to perform atomic operations (preventing race conditions).

/**
 * Fetch a single class by ID, including its current booking count.
 * Uses server-side function to bypass RLS for accurate counts.
 */
async function fetchClassDetail(classId) {
  const { data: cls, error } = await supabase
    .from('classes')
    .select('*')
    .eq('id', classId)
    .single();

  if (error) throw error;

  // Use RPC for accurate counts (bypasses RLS)
  const { data: counts, error: cErr } = await supabase
    .rpc('get_booking_counts', { p_class_ids: [classId] });

  if (cErr) throw cErr;

  const classCount = counts && counts.length > 0
    ? counts[0]
    : { confirmed_count: 0, waitlist_count: 0 };

  return {
    ...cls,
    confirmedCount: classCount.confirmed_count || 0,
    waitlistCount: classCount.waitlist_count || 0,
    spotsLeft: cls.capacity - (classCount.confirmed_count || 0)
  };
}

/**
 * Fetch the current user's booking for a specific class (if any).
 * Returns the booking row or null.
 */
async function fetchMyBooking(classId, memberId) {
  const { data, error } = await supabase
    .from('bookings')
    .select('*')
    .eq('class_id', classId)
    .eq('member_id', memberId)
    .in('status', ['confirmed', 'waitlist'])
    .maybeSingle();

  if (error) throw error;
  return data;
}

/**
 * Book a class for the current user using a server-side function.
 * Handles capacity checks, duplicate prevention, and waitlist assignment
 * atomically to prevent race conditions and overbooking.
 */
async function bookClass(classId, memberId) {
  const { data, error } = await supabase
    .rpc('book_class', { p_class_id: classId, p_member_id: memberId });

  if (error) throw error;
  return data;
}

/**
 * Cancel a booking using a server-side function.
 * Automatically promotes the next waitlisted member if applicable.
 * Both cancellation and promotion happen atomically.
 */
async function cancelBooking(bookingId, classId) {
  const session = await getSession();
  if (!session) throw new Error('You must be logged in to cancel a booking.');

  const { error } = await supabase
    .rpc('cancel_and_promote', {
      p_booking_id: bookingId,
      p_member_id: session.user.id
    });

  if (error) throw error;
}

/**
 * Fetch the current user's waitlist position for a class.
 * Uses server-side function to count across all users' bookings.
 * Returns 0 if not on waitlist, or a 1-based position.
 */
async function getWaitlistPosition(classId, memberId) {
  const { data, error } = await supabase
    .rpc('get_waitlist_position', {
      p_class_id: classId,
      p_member_id: memberId
    });

  if (error) throw error;
  return data || 0;
}

/**
 * Fetch all upcoming bookings for a member (confirmed + waitlist).
 * Uses a server-side RPC function that performs a proper JOIN with a WHERE clause
 * so only upcoming bookings are returned, rather than fetching all historical
 * bookings and filtering client-side.
 */
async function fetchMyUpcomingBookings(memberId) {
  const { data, error } = await supabase
    .rpc('get_upcoming_bookings', { p_member_id: memberId });

  if (error) throw error;

  // Reshape flat RPC rows into the nested structure expected by renderBookingsList()
  return (data || []).map(row => ({
    id: row.id,
    status: row.status,
    booked_at: row.booked_at,
    classes: {
      id: row.class_id,
      title: row.class_title,
      instructor: row.class_instructor,
      start_time: row.class_start_time,
      end_time: row.class_end_time,
      location: row.class_location,
      is_cancelled: row.class_is_cancelled
    }
  }));
}
