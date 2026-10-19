-- ==============================================================================
-- BMC E-COMMERCE: SUPABASE XENDIT PAYMENT SETUP SCRIPT
-- Run this in your Supabase Dashboard -> SQL Editor -> New Query -> Run
-- ==============================================================================

-- 1. Add Xendit tracking columns to the orders table
alter table public.orders add column if not exists xendit_invoice_id text;
alter table public.orders add column if not exists xendit_invoice_url text;

-- 2. Products table (supports both BookVerse and the BMC Finals Demo catalog)
create table if not exists public.products (
  id serial primary key,
  name text not null,
  price numeric(10, 2) not null,
  image_url text default '',
  created_at timestamptz default now()
);

-- Enable public read permissions on products table
alter table public.products enable row level security;
drop policy if exists "products: public read" on public.products;
create policy "products: public read" on public.products for select using (true);

-- 3. Seed demonstration item (Mechanical Gaming Keyboard - ₱1,500.00)
insert into public.products (name, price, image_url)
select 
  'Mechanical Gaming Keyboard', 
  1500.00, 
  'https://images.unsplash.com/photo-1595225476474-87563907a212?auto=format&fit=crop&w=600&q=80'
where not exists (
  select 1 from public.products where name = 'Mechanical Gaming Keyboard'
);

-- ==============================================================================
-- DONE!
-- ==============================================================================
