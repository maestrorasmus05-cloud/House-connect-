# HouseConnect 2.0 — Production Setup Guide

This turns the prototype into a **real** site:

| Piece | Service | Purpose |
|--------|---------|---------|
| Database + Auth + File storage | **Supabase** | Users, properties, ownership docs, photos |
| $10 listing fee | **Stripe Checkout** | Real card payments |
| Code + deploy | **GitHub → Vercel** (or Netlify) | Live public website |

You will create the accounts. I cannot log into your Supabase/Stripe/GitHub for you — that would be insecure. Follow every step below in order.

---

## STEP 1 — Create accounts (free tiers work)

1. **GitHub** — https://github.com/signup  
2. **Supabase** — https://supabase.com/dashboard → New project  
   - Note the **Project URL** and **anon / publishable key** (Settings → API)  
3. **Stripe** — https://dashboard.stripe.com/register  
   - Turn on **Test mode** first  
   - Developers → API keys → copy **Secret key** (`sk_test_...`)  
4. **Vercel** — https://vercel.com/signup (sign in with GitHub)

---

## STEP 2 — Create the database (Supabase)

1. Open your Supabase project → **SQL Editor** → New query  
2. Paste the entire contents of `supabase/schema.sql` (in this folder)  
3. Click **Run**

This creates:

- `profiles` (buyer / seller role)
- `properties` (real listings)
- `property_photos`
- `property_documents` (ownership, license, land papers — private)
- Storage buckets: `property-photos` (public), `property-documents` (private)
- Row Level Security so users only manage their own listings

---

## STEP 3 — Storage buckets (if schema did not create them)

Supabase Dashboard → **Storage**:

| Bucket | Public? |
|--------|---------|
| `property-photos` | Yes |
| `property-documents` | No |

Policies are in `schema.sql`. If uploads fail, re-run the storage policy section.

---

## STEP 4 — Stripe product ($10 listing fee)

1. Stripe Dashboard → **Products** → Add product  
   - Name: `HouseConnect Listing Fee`  
   - Price: **$10.00 USD** · One-time  
2. Copy the **Price ID** (`price_...`)  
3. Optional: Developers → Webhooks → Add endpoint later (after Edge Function deploy)

---

## STEP 5 — Supabase Edge Functions (payment)

On your computer (install [Supabase CLI](https://supabase.com/docs/guides/cli)):

```bash
# Login & link project
npx supabase login
npx supabase link --project-ref YOUR_PROJECT_REF

# Set secrets (never put these in the frontend)
npx supabase secrets set STRIPE_SECRET_KEY=sk_test_YOUR_KEY
npx supabase secrets set STRIPE_PRICE_ID=price_YOUR_PRICE_ID
npx supabase secrets set SITE_URL=http://localhost:3000

# Deploy functions
npx supabase functions deploy create-checkout
npx supabase functions deploy stripe-webhook
```

Webhook (production):

1. Stripe → Developers → Webhooks → Add endpoint  
2. URL: `https://YOUR_PROJECT_REF.supabase.co/functions/v1/stripe-webhook`  
3. Event: `checkout.session.completed`  
4. Copy signing secret →  
   `npx supabase secrets set STRIPE_WEBHOOK_SECRET=whsec_...`

---

## STEP 6 — Frontend config

1. Copy `config.example.js` → `config.js`  
2. Fill in:

```js
window.HC_CONFIG = {
  SUPABASE_URL: 'https://xxxx.supabase.co',
  SUPABASE_ANON_KEY: 'your-anon-or-publishable-key',
  STRIPE_PRICE_ID: 'price_xxxx',   // same as Edge secret
  SITE_URL: 'https://your-domain.vercel.app'
};
```

**Never** put the Stripe **secret** key in `config.js` — only the Edge Function uses it.

---

## STEP 7 — GitHub repository

```bash
cd houseconnect-production
git init
git add .
git commit -m "HouseConnect 2.0 production"
# Create empty repo on GitHub, then:
git remote add origin https://github.com/YOUR_USERNAME/houseconnect.git
git branch -M main
git push -u origin main
```

Add to `.gitignore` (already included):

```
config.js
.env
.env.local
```

Commit `config.example.js` only. Put real keys only in Vercel env vars or local `config.js` (not committed).

---

## STEP 8 — Deploy on Vercel

1. vercel.com → **Add New Project** → import the GitHub repo  
2. Framework: **Other** (static HTML)  
3. Environment variables (optional if you inject config at build):

   - `SUPABASE_URL`  
   - `SUPABASE_ANON_KEY`  

4. Deploy  
5. Set Supabase Auth → URL config → Site URL + Redirect URLs to your Vercel domain  
6. Update Stripe success/cancel URLs and `SITE_URL` secret to the Vercel URL  
7. Re-deploy Edge Functions secrets if needed

---

## STEP 9 — Go live checklist

- [ ] Sign up / log in works (Supabase Auth)  
- [ ] Switch profile to **Seller**  
- [ ] Open **List Property**, fill form, upload photos + ownership + license  
- [ ] Click **Pay $10** → Stripe Checkout (test card `4242 4242 4242 4242`)  
- [ ] After payment, listing status becomes `pending_review` or `published`  
- [ ] Globe loads properties from Supabase (not hard-coded demo array)  
- [ ] Switch Stripe to **Live mode** keys + live Price ID when ready for real money  

---

## Project files

```
houseconnect-production/
├── README.md                 ← this guide
├── index.html                ← main app (wired to Supabase)
├── config.example.js         ← copy to config.js
├── .gitignore
├── supabase/
│   ├── schema.sql            ← run in SQL Editor
│   └── functions/
│       ├── create-checkout/
│       │   └── index.ts
│       └── stripe-webhook/
│           └── index.ts
└── seed/
    └── sample-properties.sql ← optional real-looking seed data
```

---

## Honest limits

- **You** own the Supabase, Stripe, and GitHub accounts.  
- Document verification (title deeds) is **manual** until you add a review team or third-party KYC.  
- Test mode charges nothing; Live mode charges real cards.  
- Ownership PDFs stay in the **private** bucket; only you (and admins with service role) can read them.

When something fails, check:

1. Browser console  
2. Supabase → Logs  
3. Stripe → Developers → Logs  
4. Vercel → Deployments → Function logs  

Start with **STEP 1** and reply when the Supabase project exists — we can verify the schema next.
