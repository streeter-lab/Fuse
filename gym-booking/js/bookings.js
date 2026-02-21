// bookings.js - Booking, cancellation, and waitlist logic.

/**
 * Fetch a single class by ID, including its current booking count.
 */
async function fetchClassDetail(classId) {
  const { data: cls, error } = await supabase
    .from('classes')
    .select('*')
    .eq('id', classId)
    .single();

  if (error) throw error;

  // Count confirmed bookings
  const { count: confirmedCount, error: cErr } = await supabase
    .from('bookings')
    .select('*', { count: 'exact', head: true })
    .eq('class_id', classId)
    .eq('status', 'confirmed');

  if (cErr) throw cErr;

  // Count waitlist bookings
  const { count: waitlistCount, error: wErr } = await supabase
    .from('bookings')
    .select('*', { count: 'exact', head: true })
    .eq('class_id', classId)
    .eq('status', 'waitlist');

  if (wErr) throw wErr;

  return {
    ...cls,
    confirmedCount: confirmedCount || 0,
    waitlistCount: waitlistCount || 0,
    spotsLeft: cls.capacity - (confirmedCount || 0)
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
 * Book a class for the current user.
 * If the class is full, the booking is created with 'waitlist' status.
 */
async function bookClass(classId, memberId) {
  // Re-fetch to get latest availability
  const cls = await fetchClassDetail(classId);

  if (cls.is_cancelled) {
    throw new Error('This class has been cancelled.');
  }

  const status = cls.spotsLeft > 0 ? 'confirmed' : 'waitlist';

  const { data, error } = await supabase
    .from('bookings')
    .insert({
      class_id: classId,
      member_id: memberId,
      status
    })
    .select()
    .single();

  if (error) throw error;
  return data;
}

/**
 * Cancel a booking. If the cancelled booking was 'confirmed', promote
 * the earliest waitlisted booking for the same class.
 */
async function cancelBooking(bookingId, classId) {
  // Get the booking to check its status before cancelling
  const { data: booking, error: fetchErr } = await supabase
    .from('bookings')
    .select('status')
    .eq('id', bookingId)
    .single();

  if (fetchErr) throw fetchErr;

  // Mark booking as cancelled
  const { error } = await supabase
    .from('bookings')
    .update({ status: 'cancelled' })
    .eq('id', bookingId);

  if (error) throw error;

  // If the cancelled booking was confirmed, promote from waitlist
  if (booking.status === 'confirmed') {
    await promoteFromWaitlist(classId);
  }
}

/**
 * Promote the earliest waitlisted booking for a class to 'confirmed'.
 */
async function promoteFromWaitlist(classId) {
  const { data: next, error: wErr } = await supabase
    .from('bookings')
    .select('id')
    .eq('class_id', classId)
    .eq('status', 'waitlist')
    .order('booked_at', { ascending: true })
    .limit(1)
    .maybeSingle();

  if (wErr || !next) return;

  await supabase
    .from('bookings')
    .update({ status: 'confirmed' })
    .eq('id', next.id);
}

/**
 * Fetch the current user's waitlist position for a class.
 * Returns 0 if not on waitlist, or a 1-based position.
 */
async function getWaitlistPosition(classId, memberId) {
  const { data, error } = await supabase
    .from('bookings')
    .select('id, member_id')
    .eq('class_id', classId)
    .eq('status', 'waitlist')
    .order('booked_at', { ascending: true });

  if (error) throw error;

  const idx = data.findIndex(b => b.member_id === memberId);
  return idx === -1 ? 0 : idx + 1;
}

/**
 * Fetch all upcoming bookings for a member (confirmed + waitlist).
 * Joins with class data for display.
 */
async function fetchMyUpcomingBookings(memberId) {
  const now = new Date().toISOString();

  const { data, error } = await supabase
    .from('bookings')
    .select(`
      id, status, booked_at,
      classes (id, title, instructor, start_time, end_time, location, is_cancelled)
    `)
    .eq('member_id', memberId)
    .in('status', ['confirmed', 'waitlist'])
    .gte('classes.start_time', now)
    .order('booked_at', { ascending: true });

  if (error) throw error;

  // Filter out bookings where the join returned no class (past classes filtered by gte)
  return data.filter(b => b.classes);
}
