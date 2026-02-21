// supabase.js - Initialises the Supabase client used by every other module.

const SUPABASE_URL  = 'https://zszqwhmjwjnhfgpentyj.supabase.co';
const SUPABASE_ANON = 'sb_publishable_w48KQDyj-RGEWQbvhqlJOw_cDlN197C';

// createClient is exposed by the Supabase CDN script loaded in each HTML page.
if (!window.supabase || !window.supabase.createClient) {
  console.error('Supabase SDK not loaded. Check network/CDN availability.');
}
const supabase = window.supabase
  ? window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON)
  : null;
