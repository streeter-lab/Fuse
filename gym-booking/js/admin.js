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

// ── CLASS TEMPLATE CRUD ─────────────────────────────────

/**
 * Fetch all class templates ordered by day of week then start time.
 */
async function fetchAllTemplates() {
  const { data, error } = await supabase
    .from('class_templates')
    .select('*')
    .order('day_of_week', { ascending: true })
    .order('start_time', { ascending: true });

  if (error) throw error;
  return data;
}

/**
 * Create a new class template.
 */
async function createTemplate(templateData) {
  const { data, error } = await supabase
    .from('class_templates')
    .insert(templateData)
    .select()
    .single();

  if (error) throw error;
  return data;
}

/**
 * Update an existing class template by ID.
 */
async function updateTemplate(templateId, updates) {
  const { data, error } = await supabase
    .from('class_templates')
    .update(updates)
    .eq('id', templateId)
    .select()
    .single();

  if (error) throw error;
  return data;
}

/**
 * Delete a class template by ID.
 */
async function deleteTemplate(templateId) {
  const { error } = await supabase
    .from('class_templates')
    .delete()
    .eq('id', templateId);

  if (error) throw error;
}

/**
 * Toggle the is_active flag on a template.
 */
async function toggleTemplateActive(templateId, isActive) {
  return updateTemplate(templateId, { is_active: isActive });
}

/**
 * Generate bookable class instances for a given week start date (YYYY-MM-DD).
 * Returns the number of classes created.
 */
async function generateWeekClasses(weekStartDate) {
  const { data, error } = await supabase
    .rpc('generate_classes_for_week', { p_week_start: weekStartDate });

  if (error) throw error;
  return data;
}

// ── ADMIN STATS ─────────────────────────────────────────

/**
 * Fetch admin dashboard stats:
 * - Total bookings today
 * - Classes running this week
 */
async function fetchAdminStats() {
  const now = new Date();

  // Today boundaries in the admin's local timezone
  const todayStart = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  const tomorrowStart = new Date(now.getFullYear(), now.getMonth(), now.getDate() + 1);

  // This week boundaries
  const weekStart = getWeekStart(now);
  const weekEnd = new Date(weekStart);
  weekEnd.setDate(weekEnd.getDate() + 7);

  // Total bookings made today
  const { count: bookingsToday, error: e1 } = await supabase
    .from('bookings')
    .select('*', { count: 'exact', head: true })
    .gte('booked_at', todayStart.toISOString())
    .lt('booked_at', tomorrowStart.toISOString())
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
