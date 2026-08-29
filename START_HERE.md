# START HERE — Real HouseConnect (not a demo)

You asked for a **real** website with Supabase, GitHub, and real payments.  
I built the backend structure for you. **You** must create the accounts and paste the keys — that is the only secure way.

---

## What is already done in this folder

| File | What it does |
|------|----------------|
| `supabase/schema.sql` | Real tables: users, properties, photos, ownership docs, payments |
| `supabase/functions/create-checkout` | Creates a real Stripe Checkout for **$10** |
| `supabase/functions/stripe-webhook` | Marks listing **paid** after Stripe confirms |
| `config.example.js` | Template for your keys |
| `index.html` | Your HouseConnect UI (globe, sell form, profiles) |
| `README.md` | Full reference guide |

---

## Do these steps in order (today)

### 1. Supabase (15 minutes)

1. Go to https://supabase.com/dashboard → **New project**  
2. Wait until the project is ready  
3. **SQL Editor** → New query → open `supabase/schema.sql` from this folder → paste all → **Run**  
4. **Settings → API** → copy:
   - Project URL  
   - `anon` / publishable key  

### 2. Stripe (10 minutes)

1. https://dashboard.stripe.com → enable **Test mode**  
2. **Products → Add product**  
   - Name: `HouseConnect Listing Fee`  
   - Price: **$10 USD**, one-time  
3. Copy the **Price ID** (`price_...`)  
4. **Developers → API keys** → copy **Secret key** (`sk_test_...`)  

### 3. Local config

1. Copy `config.example.js` to `config.js`  
2. Paste Supabase URL + anon key + Stripe Price ID  
3. Open `index.html` in a browser (with a local server, e.g. `npx serve .`)  

### 4. Edge Functions (payment)

Install CLI once: https://supabase.com/docs/guides/cli  

```bash
cd houseconnect-production
npx supabase login
npx supabase link --project-ref YOUR_REF
npx supabase secrets set STRIPE_SECRET_KEY=sk_test_...
npx supabase secrets set STRIPE_PRICE_ID=price_...
npx supabase secrets set SITE_URL=http://localhost:3000
npx supabase functions deploy create-checkout
npx supabase functions deploy stripe-webhook
```

### 5. GitHub + Vercel

```bash
git init
git add .
git commit -m "HouseConnect production"
# create repo on github.com, then:
git remote add origin https://github.com/YOU/houseconnect.git
git push -u origin main
```

Vercel → Import repo → Deploy.  
Then set Auth redirect URLs in Supabase to your Vercel domain.

---

## What becomes “real”

- **Sign up / login** → Supabase Auth (real accounts)  
- **Seller role** → stored in `profiles`  
- **List property** → row in `properties` + files in Storage  
- **Ownership / license PDFs** → private bucket (not public)  
- **Pay $10** → Stripe Checkout (test card `4242 4242 4242 4242`)  
- **After payment** → webhook sets `payment_status = paid`, `status = pending_review`  
- **Globe** → load published rows from Supabase (next wiring step in `index.html`)

---

## What I will not do

- I will not invent fake “live” listings and claim they are real.  
- I will not put your secret keys in the repo.  
- Document verification (title deeds) still needs a human or a KYC partner later.

---

## Reply when ready

Message me when you have:

1. Supabase project created  
2. `schema.sql` run successfully  
3. Stripe test product + Price ID  

Then we wire **Auth + load properties from Supabase + Pay $10 button** into `index.html` step by step until listings are real.
