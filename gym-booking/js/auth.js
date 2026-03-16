// auth.js - Authentication helpers: login, register, logout, session guard.

/**
 * Sign up a new user with email/password and profile metadata.
 * Supabase stores the metadata in raw_user_meta_data so the
 * database trigger can copy them into the profiles table automatically.
 * Email confirmation is disabled — users can sign in immediately.
 *
 * @param {string} email
 * @param {string} password
 * @param {object} metadata - { full_name, phone, emergency_contact_name, emergency_contact_phone, medical_notes, terms_accepted }
 */
async function signUp(email, password, metadata) {
  const { data, error } = await supabase.auth.signUp({
    email,
    password,
    options: {
      data: metadata,
      emailRedirectTo: window.location.origin
    }
  });
  if (error) throw error;
  return data;
}

/**
 * Sign in with email and password.
 */
async function signIn(email, password) {
  const { data, error } = await supabase.auth.signInWithPassword({
    email,
    password
  });
  if (error) throw error;
  return data;
}

/**
 * Sign out the current user and redirect to the landing page.
 */
async function signOut() {
  const { error } = await supabase.auth.signOut();
  if (error) throw error;
  window.location.href = 'index.html';
}

/**
 * Returns the current session or null.
 */
async function getSession() {
  try {
    const { data: { session } } = await supabase.auth.getSession();
    return session;
  } catch {
    return null;
  }
}

/**
 * Returns the current user's profile row (from public.profiles).
 */
async function getProfile() {
  const session = await getSession();
  if (!session) return null;

  const { data, error } = await supabase
    .from('profiles')
    .select('*')
    .eq('id', session.user.id)
    .single();

  if (error) throw error;
  return data;
}

/**
 * Redirect away from pages that require authentication.
 * Also checks if the user's account is deactivated.
 * Call at the top of dashboard, book, admin pages.
 */
async function requireAuth() {
  const session = await getSession();
  if (!session) {
    window.location.href = 'login.html';
    return null;
  }

  // Check if account is deactivated
  try {
    const { data: profile } = await supabase
      .from('profiles')
      .select('is_active')
      .eq('id', session.user.id)
      .single();

    if (profile && profile.is_active === false) {
      await supabase.auth.signOut();
      window.location.href = 'login.html?deactivated=true';
      return null;
    }
  } catch {
    // If profile fetch fails, allow through (column may not exist yet)
  }

  return session;
}

/**
 * Redirect non-admin users away from the admin page.
 */
async function requireAdmin() {
  const session = await requireAuth();
  if (!session) return null;

  const profile = await getProfile();
  if (!profile || !profile.is_admin) {
    window.location.href = 'dashboard.html';
    return null;
  }
  return profile;
}

/**
 * Check if onboarding is complete. If not, redirect to complete-profile page.
 * Returns the profile if onboarding is complete, or null if redirected.
 */
async function requireOnboarding() {
  const profile = await getProfile();
  if (!profile) return null;

  if (profile.onboarding_complete === false) {
    window.location.href = 'complete-profile.html';
    return null;
  }
  return profile;
}

/**
 * Send a password reset email.
 */
async function resetPassword(email) {
  const { error } = await supabase.auth.resetPasswordForEmail(email, {
    redirectTo: window.location.origin + '/reset-password.html'
  });
  if (error) throw error;
}

/**
 * Update the current user's password.
 */
async function updatePassword(newPassword) {
  const { error } = await supabase.auth.updateUser({ password: newPassword });
  if (error) throw error;
}

/**
 * Bind logout buttons found on the page.
 */
function bindLogout() {
  document.querySelectorAll('.logout-btn').forEach(btn => {
    btn.addEventListener('click', async (e) => {
      e.preventDefault();
      await signOut();
    });
  });
}
