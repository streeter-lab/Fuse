// utils.js - Shared helpers used across pages.

/**
 * Escape HTML special characters to prevent XSS when inserting into innerHTML.
 */
function escapeHtml(str) {
  if (str == null) return '';
  return String(str)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

/**
 * Format a Date object or ISO string as "Mon 23 Feb".
 */
function formatDateShort(date) {
  const d = new Date(date);
  return d.toLocaleDateString('en-GB', {
    weekday: 'short', day: 'numeric', month: 'short'
  });
}

/**
 * Format a Date object or ISO string as "14:30".
 */
function formatTime(date) {
  const d = new Date(date);
  return d.toLocaleTimeString('en-GB', { hour: '2-digit', minute: '2-digit' });
}

/**
 * Format a time range like "14:30 - 15:30".
 */
function formatTimeRange(start, end) {
  return `${formatTime(start)} – ${formatTime(end)}`;
}

/**
 * Format as full date+time: "Mon 23 Feb, 14:30".
 */
function formatDateTime(date) {
  return `${formatDateShort(date)}, ${formatTime(date)}`;
}

/**
 * Return the Monday 00:00 of the week containing the given date.
 */
function getWeekStart(date) {
  const d = new Date(date);
  const day = d.getDay();
  const diff = d.getDate() - day + (day === 0 ? -6 : 1);
  const monday = new Date(d);
  monday.setDate(diff);
  monday.setHours(0, 0, 0, 0);
  return monday;
}

/**
 * Return an array of 7 Date objects (Mon-Sun) for the week containing `date`.
 */
function getWeekDays(date) {
  const start = getWeekStart(date);
  return Array.from({ length: 7 }, (_, i) => {
    const d = new Date(start);
    d.setDate(d.getDate() + i);
    return d;
  });
}

/**
 * Show a toast-style message at the top of the page.
 * type: 'success' | 'error' | 'info'
 */
function showToast(message, type = 'info') {
  // Remove any existing toast
  const existing = document.querySelector('.toast');
  if (existing) existing.remove();

  const toast = document.createElement('div');
  toast.className = `toast toast-${type}`;
  toast.textContent = message;
  document.body.prepend(toast);

  // Auto-remove after 4 seconds
  setTimeout(() => toast.remove(), 4000);
}

/**
 * Set a button to loading state (disabled + spinner text).
 */
function setLoading(button, loading) {
  if (loading) {
    button.dataset.originalText = button.textContent;
    button.textContent = 'Loading...';
    button.disabled = true;
  } else {
    button.textContent = button.dataset.originalText || button.textContent;
    button.disabled = false;
  }
}

/**
 * Simple confirmation dialog wrapper.
 */
function confirmAction(message) {
  return window.confirm(message);
}

/**
 * Parse URL query parameters. Returns an object.
 */
function getQueryParams() {
  return Object.fromEntries(new URLSearchParams(window.location.search));
}
