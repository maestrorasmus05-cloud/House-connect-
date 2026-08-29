// Copy this file to config.js and fill in your real values.
// NEVER commit config.js to GitHub.

window.HC_CONFIG = {
  // Supabase → Project Settings → API
  SUPABASE_URL: 'https://YOUR_PROJECT_REF.supabase.co',
  SUPABASE_ANON_KEY: 'YOUR_ANON_OR_PUBLISHABLE_KEY',

  // Stripe Dashboard → Products → Price ID (price_...)
  // Secret key stays ONLY in Supabase Edge Function secrets
  STRIPE_PRICE_ID: 'price_XXXXXXXX',

  // Your live site URL after Vercel deploy
  SITE_URL: 'https://your-app.vercel.app'
};
