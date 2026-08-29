-- HouseConnect 2.0 — Production schema
-- Run this entire file in Supabase → SQL Editor → Run

-- Extensions
create extension if not exists "uuid-ossp";

-- ========== PROFILES ==========
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text,
  full_name text,
  role text not null default 'buyer' check (role in ('buyer', 'seller', 'admin')),
  avatar_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

create policy "Public profiles are viewable by everyone"
  on public.profiles for select using (true);

create policy "Users can update own profile"
  on public.profiles for update using (auth.uid() = id);

create policy "Users can insert own profile"
  on public.profiles for insert with check (auth.uid() = id);

-- Auto-create profile on signup
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, email, full_name, role)
  values (
    new.id,
    new.email,
    coalesce(new.raw_user_meta_data->>'full_name', split_part(new.email, '@', 1)),
    coalesce(new.raw_user_meta_data->>'role', 'buyer')
  );
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ========== PROPERTIES ==========
create table if not exists public.properties (
  id uuid primary key default uuid_generate_v4(),
  owner_id uuid not null references public.profiles(id) on delete cascade,
  title text not null,
  description text,
  property_type text not null default 'House',
  listing_type text not null default 'For Sale' check (listing_type in ('For Sale', 'For Rent')),
  price_usd numeric(14,2) not null check (price_usd >= 0),
  currency text not null default 'USD',
  bedrooms int default 0,
  bathrooms int default 0,
  area_sqm numeric(10,2),
  country text not null,
  city text not null,
  address text,
  lat double precision,
  lng double precision,
  status text not null default 'draft'
    check (status in ('draft', 'pending_payment', 'pending_review', 'published', 'rejected', 'sold', 'rented')),
  stripe_session_id text,
  payment_status text default 'unpaid'
    check (payment_status in ('unpaid', 'paid', 'refunded', 'failed')),
  featured boolean default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  published_at timestamptz
);

create index if not exists properties_status_idx on public.properties (status);
create index if not exists properties_country_city_idx on public.properties (country, city);
create index if not exists properties_owner_idx on public.properties (owner_id);
create index if not exists properties_geo_idx on public.properties (lat, lng);

alter table public.properties enable row level security;

-- Anyone can read published listings
create policy "Published properties are public"
  on public.properties for select
  using (status = 'published' or owner_id = auth.uid());

create policy "Owners can insert properties"
  on public.properties for insert
  with check (auth.uid() = owner_id);

create policy "Owners can update own properties"
  on public.properties for update
  using (auth.uid() = owner_id);

create policy "Owners can delete own draft properties"
  on public.properties for delete
  using (auth.uid() = owner_id and status in ('draft', 'pending_payment', 'rejected'));

-- ========== PHOTOS ==========
create table if not exists public.property_photos (
  id uuid primary key default uuid_generate_v4(),
  property_id uuid not null references public.properties(id) on delete cascade,
  storage_path text not null,
  public_url text,
  sort_order int default 0,
  created_at timestamptz not null default now()
);

alter table public.property_photos enable row level security;

create policy "Photos of published or own properties"
  on public.property_photos for select
  using (
    exists (
      select 1 from public.properties p
      where p.id = property_id
        and (p.status = 'published' or p.owner_id = auth.uid())
    )
  );

create policy "Owners can manage photos"
  on public.property_photos for all
  using (
    exists (
      select 1 from public.properties p
      where p.id = property_id and p.owner_id = auth.uid()
    )
  );

-- ========== DOCUMENTS (private — ownership, license, land papers) ==========
create table if not exists public.property_documents (
  id uuid primary key default uuid_generate_v4(),
  property_id uuid not null references public.properties(id) on delete cascade,
  doc_type text not null check (doc_type in ('ownership', 'license', 'land', 'extra')),
  storage_path text not null,
  file_name text,
  created_at timestamptz not null default now()
);

alter table public.property_documents enable row level security;

-- Only owner (and service role / admin) can see documents
create policy "Only owner can view documents"
  on public.property_documents for select
  using (
    exists (
      select 1 from public.properties p
      where p.id = property_id and p.owner_id = auth.uid()
    )
  );

create policy "Owners can insert documents"
  on public.property_documents for insert
  with check (
    exists (
      select 1 from public.properties p
      where p.id = property_id and p.owner_id = auth.uid()
    )
  );

-- ========== PAYMENTS LOG ==========
create table if not exists public.payments (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid references public.profiles(id),
  property_id uuid references public.properties(id) on delete set null,
  stripe_session_id text unique,
  amount_cents int not null default 1000,
  currency text not null default 'usd',
  status text not null default 'pending',
  created_at timestamptz not null default now()
);

alter table public.payments enable row level security;

create policy "Users see own payments"
  on public.payments for select
  using (auth.uid() = user_id);

-- ========== STORAGE BUCKETS ==========
insert into storage.buckets (id, name, public)
values ('property-photos', 'property-photos', true)
on conflict (id) do nothing;

insert into storage.buckets (id, name, public)
values ('property-documents', 'property-documents', false)
on conflict (id) do nothing;

-- Photos: public read, authenticated upload to own folder
create policy "Public read property photos"
  on storage.objects for select
  using (bucket_id = 'property-photos');

create policy "Authenticated upload property photos"
  on storage.objects for insert
  with check (
    bucket_id = 'property-photos'
    and auth.role() = 'authenticated'
  );

create policy "Owners update/delete own photos"
  on storage.objects for update
  using (bucket_id = 'property-photos' and auth.role() = 'authenticated');

create policy "Owners delete own photos"
  on storage.objects for delete
  using (bucket_id = 'property-photos' and auth.role() = 'authenticated');

-- Documents: private — only authenticated owner path
create policy "Owners read own documents"
  on storage.objects for select
  using (
    bucket_id = 'property-documents'
    and auth.role() = 'authenticated'
  );

create policy "Owners upload documents"
  on storage.objects for insert
  with check (
    bucket_id = 'property-documents'
    and auth.role() = 'authenticated'
  );

create policy "Owners delete own documents"
  on storage.objects for delete
  using (
    bucket_id = 'property-documents'
    and auth.role() = 'authenticated'
  );

-- ========== HELPER: publish after paid ==========
create or replace function public.mark_property_paid(p_session_id text)
returns void
language plpgsql
security definer set search_path = public
as $$
begin
  update public.properties
  set payment_status = 'paid',
      status = 'pending_review',
      updated_at = now()
  where stripe_session_id = p_session_id;

  update public.payments
  set status = 'paid'
  where stripe_session_id = p_session_id;
end;
$$;
