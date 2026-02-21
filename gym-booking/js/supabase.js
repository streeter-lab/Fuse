// supabase.js - Initialises the Supabase client used by every other module.
//
// The CDN UMD bundle assigns the SDK to `var supabase` on window.
// We intentionally re-assign that same global with the *client* instance
// so every other script can simply reference `supabase.from(...)` etc.

var SUPABASE_URL  = 'https://zszqwhmjwjnhfgpentyj.supabase.co';
var SUPABASE_ANON = 'sb_publishable_w48KQDyj-RGEWQbvhqlJOw_cDlN197C';

var supabase = supabase.createClient(SUPABASE_URL, SUPABASE_ANON);
