// auth.js - Authentication helpers: login, register, logout, session guard.

/**
 * Sign up a new user with email/password and profile metadata.
 * Supabase stores full_name and phone in raw_user_meta_data so the
 * database trigger can copy them into the profiles table automatically.
 */
async function signUp(email, password, fullName, phone) {
  const { data, error } = await supabase.auth.signUp({
    email,
    password,
    options: {
      data: { full_name: fullName, phone }
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
  const { data: { session } } = await supabase.auth.getSession();
  return session;
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
 * Call at the top of dashboard, book, admin pages.
 */
async function requireAuth() {
  const session = await getSession();
  if (!session) {
    window.location.href = 'login.html';
    return null;
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
