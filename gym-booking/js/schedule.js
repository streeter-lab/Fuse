// schedule.js - Fetches classes from Supabase and renders a week-view schedule.

/**
 * Fetch all non-cancelled classes for a given week (Mon 00:00 to Sun 23:59).
 * Also fetches confirmed+waitlist booking counts per class so we can show
 * remaining spots.
 */
async function fetchWeekClasses(weekStart) {
  const weekEnd = new Date(weekStart);
  weekEnd.setDate(weekEnd.getDate() + 7);

  const { data: classes, error } = await supabase
    .from('classes')
    .select('*')
    .gte('start_time', weekStart.toISOString())
    .lt('start_time', weekEnd.toISOString())
    .order('start_time', { ascending: true });

  if (error) throw error;

  // Fetch booking counts using server-side function (bypasses RLS for accurate counts)
  const classIds = classes.map(c => c.id);
  let bookingCounts = {};

  if (classIds.length > 0) {
    const { data: counts, error: bErr } = await supabase
      .rpc('get_booking_counts', { p_class_ids: classIds });

    if (bErr) throw bErr;

    // Build lookup by class_id
    if (counts) {
      counts.forEach(c => {
        bookingCounts[c.class_id] = c.confirmed_count || 0;
      });
    }
  }

  // Attach spots info to each class
  return classes.map(c => ({
    ...c,
    booked: bookingCounts[c.id] || 0,
    spotsLeft: c.capacity - (bookingCounts[c.id] || 0)
  }));
}

/**
 * Render the week navigation bar with prev/next buttons and week label.
 */
function renderWeekNav(container, currentWeek, onChange) {
  const days = getWeekDays(currentWeek);
  const label = `${formatDateShort(days[0])} – ${formatDateShort(days[6])}`;

  container.innerHTML = `
    <button class="btn btn-sm btn-outline" id="prev-week">&larr; Prev</button>
    <h2>${label}</h2>
    <button class="btn btn-sm btn-outline" id="next-week">Next &rarr;</button>
  `;

  document.getElementById('prev-week').addEventListener('click', () => {
    const prev = new Date(currentWeek);
    prev.setDate(prev.getDate() - 7);
    onChange(prev);
  });

  document.getElementById('next-week').addEventListener('click', () => {
    const next = new Date(currentWeek);
    next.setDate(next.getDate() + 7);
    onChange(next);
  });
}

/**
 * Render the 7-day schedule grid from an array of class objects.
 * membershipType is used to show booking window indicators.
 */
function renderScheduleGrid(container, classes, weekStart, membershipType) {
  const days = getWeekDays(weekStart);
  const now = new Date();
  const maxDays = membershipType === 'premium' ? 14 : 7;
  const bookingCutoff = new Date(now.getTime() + maxDays * 24 * 60 * 60 * 1000);

  // Group classes by day-of-week index (0=Mon ... 6=Sun)
  const grouped = {};
  days.forEach((_, i) => { grouped[i] = []; });

  classes.forEach(c => {
    const d = new Date(c.start_time);
    // Convert JS day (0=Sun) to our index (0=Mon)
    const jsDay = d.getDay();
    const idx = jsDay === 0 ? 6 : jsDay - 1;
    if (grouped[idx]) grouped[idx].push(c);
  });

  let html = '';

  days.forEach((day, i) => {
    const isToday = day.toDateString() === new Date().toDateString();
    html += `<div class="day-column${isToday ? ' today' : ''}">`;
    html += `<h3>${formatDateShort(day)}</h3>`;

    if (grouped[i].length === 0) {
      html += `<p class="empty-day" style="font-size:0.8rem;color:var(--color-text-muted);padding:0.5rem 0;">No classes</p>`;
    }

    grouped[i].forEach(c => {
      const classStart = new Date(c.start_time);
      const outsideWindow = membershipType && classStart > bookingCutoff;

      const spotsClass = c.is_cancelled ? '' :
        outsideWindow ? 'not-bookable' :
        c.spotsLeft > 3 ? 'available' :
        c.spotsLeft > 0 ? 'low' : 'full';

      const spotsText = c.is_cancelled ? 'Cancelled' :
        outsideWindow ? (membershipType === 'standard' ? 'Premium early access' : 'Not yet available') :
        c.spotsLeft > 0 ? `${c.spotsLeft} spots left` : 'Full';

      const cancelledClass = c.is_cancelled ? ' cancelled' : '';
      const notBookableClass = outsideWindow ? ' not-bookable-card' : '';
      const href = c.is_cancelled ? '#' : `book.html?id=${c.id}`;

      html += `
        <a href="${href}" class="class-card${cancelledClass}${notBookableClass}" style="display:block;text-decoration:none;color:inherit;">
          <div class="class-title">${escapeHtml(c.title)}</div>
          <div class="class-meta">${formatTimeRange(c.start_time, c.end_time)} &middot; ${escapeHtml(c.location)}</div>
          <div class="class-meta">${escapeHtml(c.instructor)}</div>
          <span class="spots ${spotsClass}">${spotsText}</span>
        </a>
      `;
    });

    html += `</div>`;
  });

  container.innerHTML = html;
}

/**
 * Main initialiser for the schedule page. Call on DOMContentLoaded.
 */
async function initSchedule() {
  const weekNav = document.getElementById('week-nav');
  const grid = document.getElementById('schedule-grid');

  let currentWeek = getWeekStart(new Date());

  // Try to get membership type if logged in
  let membershipType = null;
  try {
    const session = await getSession();
    if (session) {
      const { data: profile } = await supabase
        .from('profiles')
        .select('membership_type')
        .eq('id', session.user.id)
        .single();
      if (profile) membershipType = profile.membership_type;
    }
  } catch {
    // Not logged in or profile unavailable
  }

  async function loadWeek(weekStart) {
    currentWeek = weekStart;
    renderWeekNav(weekNav, currentWeek, loadWeek);
    grid.innerHTML = '<div class="spinner"></div>';

    try {
      const fetchPromise = fetchWeekClasses(currentWeek);
      const timeoutPromise = new Promise((_, reject) =>
        setTimeout(() => reject(new Error('Request timed out')), 10000)
      );

      const classes = await Promise.race([fetchPromise, timeoutPromise]);
      renderScheduleGrid(grid, classes, currentWeek, membershipType);
    } catch (err) {
      grid.innerHTML = `
        <div class="empty-state">
          <p>Unable to load the schedule. Please check your connection and try again.</p>
          <button class="btn btn-primary" id="retry-schedule">Retry</button>
        </div>`;
      document.getElementById('retry-schedule').addEventListener('click', () => loadWeek(currentWeek));
    }
  }

  await loadWeek(currentWeek);
}
