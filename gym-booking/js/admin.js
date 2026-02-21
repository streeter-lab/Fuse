// admin.js - Admin CRUD operations for classes and booking management.

/**
 * Fetch all classes ordered by start_time descending (newest first).
 */
async function fetchAllClasses() {
  const { data, error } = await supabase
    .from('classes')
    .select('*')
    .order('start_time', { ascending: false });

  if (error) throw error;
  return data;
}

/**
 * Create a new class.
 */
async function createClass(classData) {
  const { data, error } = await supabase
    .from('classes')
    .insert(classData)
    .select()
    .single();

  if (error) throw error;
  return data;
}

/**
 * Update an existing class by ID.
 */
async function updateClass(classId, updates) {
  const { data, error } = await supabase
    .from('classes')
    .update(updates)
    .eq('id', classId)
    .select()
    .single();

  if (error) throw error;
  return data;
}

/**
 * Toggle the is_cancelled flag on a class.
 */
async function toggleCancelClass(classId, isCancelled) {
  return updateClass(classId, { is_cancelled: isCancelled });
}

/**
 * Fetch all bookings for a specific class, joined with member profiles.
 */
async function fetchClassBookings(classId) {
  const { data, error } = await supabase
    .from('bookings')
    .select(`
      id, status, booked_at,
      profiles (id, full_name, phone, membership_type)
    `)
    .eq('class_id', classId)
    .in('status', ['confirmed', 'waitlist'])
    .order('booked_at', { ascending: true });

  if (error) throw error;
  return data;
}

/**
 * Fetch admin dashboard stats:
 * - Total bookings today
 * - Classes running this week
 */
async function fetchAdminStats() {
  const now = new Date();

  // Today boundaries
  const todayStart = new Date(now);
  todayStart.setHours(0, 0, 0, 0);
  const todayEnd = new Date(now);
  todayEnd.setHours(23, 59, 59, 999);

  // This week boundaries
  const weekStart = getWeekStart(now);
  const weekEnd = new Date(weekStart);
  weekEnd.setDate(weekEnd.getDate() + 7);

  // Total bookings made today
  const { count: bookingsToday, error: e1 } = await supabase
    .from('bookings')
    .select('*', { count: 'exact', head: true })
    .gte('booked_at', todayStart.toISOString())
    .lte('booked_at', todayEnd.toISOString())
    .in('status', ['confirmed', 'waitlist']);

  if (e1) throw e1;

  // Classes running this week (not cancelled)
  const { count: classesThisWeek, error: e2 } = await supabase
    .from('classes')
    .select('*', { count: 'exact', head: true })
    .gte('start_time', weekStart.toISOString())
    .lt('start_time', weekEnd.toISOString())
    .eq('is_cancelled', false);

  if (e2) throw e2;

  // Total active members (profiles count)
  const { count: totalMembers, error: e3 } = await supabase
    .from('profiles')
    .select('*', { count: 'exact', head: true });

  if (e3) throw e3;

  return {
    bookingsToday: bookingsToday || 0,
    classesThisWeek: classesThisWeek || 0,
    totalMembers: totalMembers || 0
  };
}
