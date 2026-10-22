-- =============================================================================
-- BookVerse — Supabase schema
--
-- Run this whole file once in the Supabase dashboard → SQL Editor → New query
-- → paste → Run. It is safe to re-run (everything is "if not exists" /
-- "create or replace" / drop-then-create for policies and triggers).
--
-- Replaces the old Firebase setup: Firestore collections → tables below,
-- firestore.rules → Row Level Security policies, storage.rules → storage
-- policies at the bottom.
-- =============================================================================

create extension if not exists pgcrypto;

-- -----------------------------------------------------------------------------
-- Helpers
-- -----------------------------------------------------------------------------

-- Generic "touch updated_at on every update" trigger function.
create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at := now();
  return new;
end $$;

-- -----------------------------------------------------------------------------
-- Profiles (was Firestore users/{uid})
-- -----------------------------------------------------------------------------

create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  email text not null default '',
  display_name text not null default '',
  photo_url text,
  badge_ids text[] not null default '{}',
  streak_count int not null default 0,
  longest_streak int not null default 0,
  last_read_at timestamptz,
  books_completed_count int not null default 0,
  -- Read-only mirror of user_roles (admin / super_admin) for the app to show
  -- the Admin Panel. The source of truth is user_roles below.
  is_admin boolean not null default false,
  created_at timestamptz not null default now()
);

-- -----------------------------------------------------------------------------
-- Roles. Everyone is a customer; extra roles live here and are only ever
-- written by trusted functions (seller approval, set_user_role) or the SQL
-- editor — never by the app directly.
-- -----------------------------------------------------------------------------

create table if not exists public.user_roles (
  user_id uuid not null references auth.users (id) on delete cascade,
  role text not null check (role in ('seller', 'admin', 'super_admin')),
  granted_by uuid references auth.users (id) on delete set null,
  granted_at timestamptz not null default now(),
  primary key (user_id, role)
);
alter table public.user_roles enable row level security;
revoke insert, update, delete on public.user_roles from anon, authenticated;

-- SECURITY DEFINER so policies can call these without recursing into RLS.
create or replace function public.has_role(p_role text)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.user_roles where user_id = auth.uid() and role = p_role);
$$;

create or replace function public.is_admin()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.user_roles where user_id = auth.uid() and role in ('admin', 'super_admin'));
$$;

-- True for writes made by our own SECURITY DEFINER functions (place_order,
-- review triggers…) and the SQL editor; false for direct API calls, which
-- always run as anon/authenticated. Guard triggers use it to let trusted
-- writes through, so those guards must stay SECURITY INVOKER.
create or replace function public.is_trusted()
returns boolean language sql stable as $$
  select current_user not in ('anon', 'authenticated');
$$;

drop policy if exists "user_roles: read own or admin" on public.user_roles;
create policy "user_roles: read own or admin" on public.user_roles
  for select using (user_id = auth.uid() or public.is_admin());

-- Pre-roles setups marked admins with profiles.is_admin; carry them over.
insert into public.user_roles (user_id, role)
select id, 'super_admin' from public.profiles where is_admin
on conflict do nothing;

create or replace function public.sync_profile_admin_flag()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := case when tg_op = 'DELETE' then old.user_id else new.user_id end;
begin
  update profiles set is_admin = exists (
    select 1 from user_roles where user_id = v_uid and role in ('admin', 'super_admin')
  ) where id = v_uid;
  return null;
end $$;
drop trigger if exists user_roles_sync_admin on public.user_roles;
create trigger user_roles_sync_admin after insert or delete on public.user_roles
  for each row execute function public.sync_profile_admin_flag();

-- -----------------------------------------------------------------------------
-- Admin audit log — written only by the admin functions in this file.
-- -----------------------------------------------------------------------------

create table if not exists public.admin_audit_logs (
  id bigint generated always as identity primary key,
  actor_id uuid references auth.users (id) on delete set null,
  action text not null,
  target_type text not null,
  target_id text,
  details jsonb not null default '{}',
  created_at timestamptz not null default now()
);
create index if not exists admin_audit_logs_created_idx on public.admin_audit_logs (created_at desc);
alter table public.admin_audit_logs enable row level security;
revoke insert, update, delete on public.admin_audit_logs from anon, authenticated;
drop policy if exists "admin_audit_logs: admin read" on public.admin_audit_logs;
create policy "admin_audit_logs: admin read" on public.admin_audit_logs
  for select using (public.is_admin());

create or replace function public.log_admin_action(
  p_action text, p_target_type text, p_target_id text, p_details jsonb default '{}'
) returns void language sql security definer set search_path = public as $$
  insert into admin_audit_logs (actor_id, action, target_type, target_id, details)
  values (auth.uid(), p_action, p_target_type, p_target_id, coalesce(p_details, '{}'));
$$;
revoke execute on function public.log_admin_action(text, text, text, jsonb) from public, anon, authenticated;

-- Super admins grant or revoke admin rights. (Seller rights come only from an
-- approved seller application.)
create or replace function public.set_user_role(p_user_id uuid, p_role text, p_grant boolean)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.has_role('super_admin') then
    raise exception 'Only a super admin can change admin roles' using errcode = '42501';
  end if;
  if p_role not in ('admin', 'super_admin') then
    raise exception 'Unknown admin role: %', p_role;
  end if;
  if not p_grant and p_user_id = auth.uid() and p_role = 'super_admin' then
    raise exception 'You cannot remove your own super admin role';
  end if;

  if p_grant then
    insert into user_roles (user_id, role, granted_by) values (p_user_id, p_role, auth.uid())
    on conflict do nothing;
  else
    delete from user_roles where user_id = p_user_id and role = p_role;
  end if;
  perform log_admin_action(case when p_grant then 'role.grant' else 'role.revoke' end,
                           'user', p_user_id::text, jsonb_build_object('role', p_role));
end $$;
revoke execute on function public.set_user_role(uuid, text, boolean) from public, anon;

-- Creates the profile row (and the welcome notification) the moment an
-- account is created — server-side, in the same transaction as the signup.
-- With Firebase this was a separate client write that could fail after the
-- account already existed ("signup failed, but I can log in").
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, email, display_name, photo_url)
  values (
    new.id,
    coalesce(new.email, ''),
    coalesce(
      new.raw_user_meta_data ->> 'display_name',
      new.raw_user_meta_data ->> 'full_name',
      new.raw_user_meta_data ->> 'name',
      ''
    ),
    new.raw_user_meta_data ->> 'avatar_url'
  )
  on conflict (id) do nothing;

  insert into public.notifications (user_id, category, title, body)
  values (
    new.id,
    'announcement',
    'Welcome to BookVerse!',
    'Browse the catalog, save your favorites, and check the Vouchers tab for your first-order discount.'
  );
  return new;
end $$;

-- Replaced by user_roles + column grants below.
drop trigger if exists profiles_guard_admin on public.profiles;
drop function if exists public.guard_profile_admin_flag();

alter table public.profiles enable row level security;
drop policy if exists "profiles: read own" on public.profiles;
create policy "profiles: read own" on public.profiles
  for select using (id = auth.uid() or public.is_admin());
drop policy if exists "profiles: update own" on public.profiles;
create policy "profiles: update own" on public.profiles
  for update using (id = auth.uid()) with check (id = auth.uid());
-- Users may edit only their name and avatar. Streaks, badges and the admin
-- flag are written server-side (update_reading_progress, user_roles).
revoke update on public.profiles from anon, authenticated;
grant update (display_name, photo_url) on public.profiles to authenticated;

-- Lets a signed-in user delete their own account (the anon key can't call
-- the auth admin API). Deleting the auth user cascades to every table below.
create or replace function public.delete_my_account()
returns void language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then
    raise exception 'not signed in';
  end if;
  delete from auth.users where id = auth.uid();
end $$;
revoke all on function public.delete_my_account() from public, anon;
grant execute on function public.delete_my_account() to authenticated;

-- -----------------------------------------------------------------------------
-- Marketplace: platform settings, stores, seller applications
-- -----------------------------------------------------------------------------

-- Single-row settings table. Change the rate from the SQL editor for now;
-- each order item snapshots the rate it was sold at.
create table if not exists public.platform_settings (
  id boolean primary key default true check (id),
  commission_rate numeric(5, 4) not null default 0.10 check (commission_rate between 0 and 1),
  updated_at timestamptz not null default now()
);
insert into public.platform_settings default values on conflict do nothing;
alter table public.platform_settings enable row level security;
revoke insert, update, delete on public.platform_settings from anon, authenticated;
drop policy if exists "platform_settings: public read" on public.platform_settings;
create policy "platform_settings: public read" on public.platform_settings for select using (true);

create table if not exists public.stores (
  id uuid primary key default gen_random_uuid(),
  -- null owner = the platform's own "BookVerse Official" store (run by admins)
  owner_id uuid unique references auth.users (id) on delete set null,
  name text not null check (length(trim(name)) between 2 and 80),
  description text not null default '',
  contact_email text not null default '',
  contact_phone text not null default '',
  status text not null default 'active' check (status in ('active', 'suspended')),
  -- null = use platform_settings.commission_rate
  commission_rate numeric(5, 4) check (commission_rate between 0 and 1),
  is_official boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create unique index if not exists stores_one_official on public.stores (is_official) where is_official;
drop trigger if exists stores_updated_at on public.stores;
create trigger stores_updated_at before update on public.stores
  for each row execute function public.set_updated_at();

insert into public.stores (name, description, is_official)
select 'BookVerse Official', 'Books and comics sold directly by BookVerse.', true
where not exists (select 1 from public.stores where is_official);

alter table public.stores enable row level security;
drop policy if exists "stores: read" on public.stores;
create policy "stores: read" on public.stores
  for select using (status = 'active' or owner_id = auth.uid() or public.is_admin());
drop policy if exists "stores: owner or admin edit" on public.stores;
create policy "stores: owner or admin edit" on public.stores
  for update using (owner_id = auth.uid() or public.is_admin())
  with check (owner_id = auth.uid() or public.is_admin());
-- Profile fields only; status and commission go through admin functions.
revoke insert, update, delete on public.stores from anon, authenticated;
grant update (name, description, contact_email, contact_phone) on public.stores to authenticated;

-- The caller's store, if they are an approved seller whose store is active.
create or replace function public.my_store_id()
returns uuid language sql stable security definer set search_path = public as $$
  select s.id from public.stores s
  where s.owner_id = auth.uid() and s.status = 'active'
    and exists (select 1 from public.user_roles r where r.user_id = auth.uid() and r.role = 'seller');
$$;

create table if not exists public.seller_applications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  store_name text not null check (length(trim(store_name)) between 2 and 80),
  description text not null default '',
  contact_email text not null default '',
  contact_phone text not null default '',
  status text not null default 'pending' check (status in ('pending', 'approved', 'rejected')),
  admin_note text,
  reviewed_by uuid references auth.users (id) on delete set null,
  reviewed_at timestamptz,
  created_at timestamptz not null default now()
);
create unique index if not exists seller_applications_one_open
  on public.seller_applications (user_id) where status = 'pending';
create index if not exists seller_applications_status_idx
  on public.seller_applications (status, created_at);

alter table public.seller_applications enable row level security;
drop policy if exists "seller_applications: read own or admin" on public.seller_applications;
create policy "seller_applications: read own or admin" on public.seller_applications
  for select using (user_id = auth.uid() or public.is_admin());
-- Apply for yourself, as pending, only if you don't already have a store,
-- and not as an admin (admins would be approving their own listings).
drop policy if exists "seller_applications: apply" on public.seller_applications;
create policy "seller_applications: apply" on public.seller_applications
  for insert with check (
    user_id = auth.uid() and status = 'pending'
    and admin_note is null and reviewed_by is null and reviewed_at is null
    and not exists (select 1 from public.stores where owner_id = auth.uid())
    and not public.is_admin()
  );
revoke update, delete on public.seller_applications from anon, authenticated;

create or replace function public.review_seller_application(
  p_application_id uuid, p_approve boolean, p_note text default null
) returns uuid language plpgsql security definer set search_path = public as $$
declare
  a seller_applications;
  v_store_id uuid;
begin
  if not public.is_admin() then
    raise exception 'Only an admin can review seller applications' using errcode = '42501';
  end if;
  select * into a from seller_applications where id = p_application_id for update;
  if not found then
    raise exception 'Application not found';
  end if;
  if a.status <> 'pending' then
    raise exception 'This application was already reviewed';
  end if;
  if a.user_id = auth.uid() then
    raise exception 'You cannot review your own application' using errcode = '42501';
  end if;
  if not p_approve and coalesce(trim(p_note), '') = '' then
    raise exception 'Give the applicant a reason for the rejection';
  end if;

  update seller_applications set
    status = case when p_approve then 'approved' else 'rejected' end,
    admin_note = nullif(trim(p_note), ''),
    reviewed_by = auth.uid(),
    reviewed_at = now()
  where id = a.id;

  if p_approve then
    insert into stores (owner_id, name, description, contact_email, contact_phone)
    values (a.user_id, a.store_name, a.description, a.contact_email, a.contact_phone)
    returning id into v_store_id;
    insert into user_roles (user_id, role, granted_by) values (a.user_id, 'seller', auth.uid())
    on conflict do nothing;
  end if;

  insert into notifications (user_id, category, title, body)
  values (
    a.user_id, 'announcement',
    case when p_approve then 'Your store is approved!' else 'Seller application not approved' end,
    case when p_approve
      then 'Welcome aboard, ' || a.store_name || '. You can now list products for review.'
      else 'Reason: ' || trim(p_note) || ' You can update your details and apply again.'
    end
  );
  perform log_admin_action(case when p_approve then 'seller.approve' else 'seller.reject' end,
                           'seller_application', a.id::text,
                           jsonb_build_object('user_id', a.user_id, 'note', p_note));
  return v_store_id;
end $$;
revoke execute on function public.review_seller_application(uuid, boolean, text) from public, anon;

create or replace function public.set_store_status(p_store_id uuid, p_status text, p_reason text)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_owner uuid;
begin
  if not public.is_admin() then
    raise exception 'Only an admin can suspend or reinstate stores' using errcode = '42501';
  end if;
  if p_status not in ('active', 'suspended') then
    raise exception 'Unknown store status: %', p_status;
  end if;
  if coalesce(trim(p_reason), '') = '' then
    raise exception 'Give a reason for this change';
  end if;
  update stores set status = p_status where id = p_store_id returning owner_id into v_owner;
  if not found then
    raise exception 'Store not found';
  end if;
  if v_owner is not null then
    insert into notifications (user_id, category, title, body)
    values (v_owner, 'announcement',
            case when p_status = 'suspended' then 'Your store was suspended' else 'Your store was reinstated' end,
            'Reason: ' || trim(p_reason));
  end if;
  perform log_admin_action('store.' || p_status, 'store', p_store_id::text,
                           jsonb_build_object('reason', p_reason));
end $$;
revoke execute on function public.set_store_status(uuid, text, text) from public, anon;

-- -----------------------------------------------------------------------------
-- Books / products (was Firestore books)
-- Add products here from Table Editor → books → Insert row.
-- -----------------------------------------------------------------------------

create table if not exists public.books (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  author text not null default 'Unknown',
  cover_url text not null default '',
  price numeric(10, 2) not null default 0 check (price >= 0),
  stock int not null default 0 check (stock >= 0),
  type text not null default 'other' check (type in
    ('book', 'manga', 'manhwa', 'manhua', 'comic', 'novel', 'lightNovel', 'textbook', 'academic', 'other')),
  genres text[] not null default '{}',
  format text not null default 'paperback' check (format in ('paperback', 'hardcover', 'digital')),
  language text not null default 'English',
  publisher text not null default '',
  pages int,
  isbn text,
  rating numeric(2, 1) not null default 0 check (rating between 0 and 5),
  rating_count int not null default 0,
  release_date date,
  description text not null default '',
  tags text[] not null default '{}',
  -- Any of: nowReading, forYou, trending, newReleases (Home tab rails)
  featured_sections text[] not null default '{}',
  total_chapters int,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists books_created_at_idx on public.books (created_at desc);
create index if not exists books_type_idx on public.books (type);
create index if not exists books_featured_idx on public.books using gin (featured_sections);

drop trigger if exists books_updated_at on public.books;
create trigger books_updated_at before update on public.books
  for each row execute function public.set_updated_at();

-- Marketplace columns. Existing books join the official store, already published.
alter table public.books add column if not exists store_id uuid references public.stores (id) on delete restrict;
alter table public.books add column if not exists listing_status text not null default 'published'
  check (listing_status in ('draft', 'pending_review', 'published', 'rejected', 'suspended', 'archived'));
alter table public.books add column if not exists moderation_note text;
update public.books set store_id = (select id from public.stores where is_official) where store_id is null;
alter table public.books alter column store_id set not null;
create index if not exists books_store_idx on public.books (store_id);
create index if not exists books_listing_status_idx on public.books (listing_status);

-- Sellers can't publish, move listings between stores, or touch ratings and
-- the Home rails; admins and trusted functions can. Must stay SECURITY
-- INVOKER (see is_trusted).
create or replace function public.guard_book_write()
returns trigger language plpgsql set search_path = public as $$
begin
  if public.is_trusted() or public.is_admin() then
    if new.store_id is null then
      new.store_id := (select id from stores where is_official);
    end if;
    return new;
  end if;

  -- Marketplace rule: sellers sell books only — no merchandise or other items.
  -- Keep in sync with lib/features/seller/presentation/seller_rules.dart.
  if new.type = 'other' then
    raise exception 'Sellers can only list books (manga, manhwa, manhua, comics, novels, textbooks…), not other items.'
      using errcode = '42501';
  end if;

  if tg_op = 'INSERT' then
    new.store_id := coalesce(new.store_id, public.my_store_id());
    new.rating := 0;
    new.rating_count := 0;
    new.featured_sections := '{}';
    new.moderation_note := null;
    if new.listing_status not in ('draft', 'pending_review') then
      new.listing_status := 'pending_review';
    end if;
    return new;
  end if;

  new.store_id := old.store_id;
  new.rating := old.rating;
  new.rating_count := old.rating_count;
  new.featured_sections := old.featured_sections;
  new.moderation_note := old.moderation_note;
  if new.listing_status is distinct from old.listing_status
     and (old.listing_status = 'suspended' or new.listing_status not in ('draft', 'pending_review', 'archived')) then
    raise exception 'Only an admin can publish, reject or suspend a listing' using errcode = '42501';
  end if;
  return new;
end $$;
drop trigger if exists books_guard_write on public.books;
create trigger books_guard_write before insert or update on public.books
  for each row execute function public.guard_book_write();

alter table public.books enable row level security;
drop policy if exists "books: public read" on public.books;
drop policy if exists "books: read" on public.books;
-- Shoppers see published listings from active stores; sellers also see their
-- own drafts; admins see everything.
create policy "books: read" on public.books for select using (
  (listing_status = 'published'
    and exists (select 1 from public.stores s where s.id = store_id and s.status = 'active'))
  or exists (select 1 from public.stores s where s.id = store_id and s.owner_id = auth.uid())
  or public.is_admin()
);
drop policy if exists "books: admin write" on public.books;
create policy "books: admin write" on public.books for all
  using (public.is_admin()) with check (public.is_admin());
-- Sellers add and edit listings in their own active store. No deletes —
-- archive instead, so past orders keep their product link.
drop policy if exists "books: seller insert" on public.books;
create policy "books: seller insert" on public.books for insert to authenticated
  with check (store_id = public.my_store_id());
drop policy if exists "books: seller update" on public.books;
create policy "books: seller update" on public.books for update to authenticated
  using (store_id = public.my_store_id()) with check (store_id = public.my_store_id());

-- Admin review of a seller's listing: publish, reject or suspend (with a
-- reason the seller sees), audited.
create or replace function public.moderate_listing(p_book_id uuid, p_status text, p_note text default null)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_title text;
  v_store_id uuid;
  v_owner uuid;
begin
  if not public.is_admin() then
    raise exception 'Only an admin can moderate listings' using errcode = '42501';
  end if;
  if p_status not in ('published', 'rejected', 'suspended') then
    raise exception 'Unknown listing status: %', p_status;
  end if;
  if p_status <> 'published' and coalesce(trim(p_note), '') = '' then
    raise exception 'Give the seller a reason';
  end if;

  update books set listing_status = p_status, moderation_note = nullif(trim(p_note), '')
  where id = p_book_id
  returning title, store_id into v_title, v_store_id;
  if not found then
    raise exception 'Listing not found';
  end if;

  select owner_id into v_owner from stores where id = v_store_id;
  if v_owner is not null then
    insert into notifications (user_id, category, title, body)
    values (v_owner, 'announcement',
            case p_status when 'published' then 'Listing approved' when 'rejected' then 'Listing rejected'
                          else 'Listing suspended' end,
            '"' || v_title || '"' || case when p_status = 'published' then ' is now live in the store.'
                                          else ' — ' || trim(p_note) end);
  end if;
  perform log_admin_action('listing.' || p_status, 'book', p_book_id::text, jsonb_build_object('note', p_note));
end $$;
revoke execute on function public.moderate_listing(uuid, text, text) from public, anon;

-- -----------------------------------------------------------------------------
-- Per-user shopping data (was users/{uid}/cart, /wishlist, /library,
-- /collections, /addresses)
-- -----------------------------------------------------------------------------

create table if not exists public.cart_items (
  user_id uuid not null references auth.users (id) on delete cascade,
  book_id uuid not null references public.books (id) on delete cascade,
  quantity int not null default 1 check (quantity > 0),
  added_at timestamptz not null default now(),
  primary key (user_id, book_id)
);

create table if not exists public.wishlist_items (
  user_id uuid not null references auth.users (id) on delete cascade,
  book_id uuid not null references public.books (id) on delete cascade,
  added_at timestamptz not null default now(),
  primary key (user_id, book_id)
);

create table if not exists public.library_entries (
  user_id uuid not null references auth.users (id) on delete cascade,
  book_id uuid not null references public.books (id) on delete cascade,
  shelf text not null default 'wantToRead'
    check (shelf in ('currentlyReading', 'completed', 'wantToRead', 'favorites')),
  progress_percent numeric not null default 0,
  current_chapter int not null default 0,
  is_favorite boolean not null default false,
  started_at timestamptz,
  completed_at timestamptz,
  updated_at timestamptz not null default now(),
  primary key (user_id, book_id)
);
drop trigger if exists library_entries_updated_at on public.library_entries;
create trigger library_entries_updated_at before update on public.library_entries
  for each row execute function public.set_updated_at();

create table if not exists public.collections (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  title text not null default 'Untitled collection',
  description text not null default '',
  book_ids uuid[] not null default '{}',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists collections_user_idx on public.collections (user_id);
drop trigger if exists collections_updated_at on public.collections;
create trigger collections_updated_at before update on public.collections
  for each row execute function public.set_updated_at();

create table if not exists public.addresses (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  label text not null default 'Home',
  recipient_name text not null default '',
  phone_number text not null default '',
  address_line text not null default '',
  city text not null default '',
  province text not null default '',
  postal_code text not null default '',
  is_default boolean not null default false
);
create index if not exists addresses_user_idx on public.addresses (user_id);

-- Only one default address per user: setting one clears the others.
create or replace function public.single_default_address()
returns trigger language plpgsql as $$
begin
  if new.is_default then
    update public.addresses set is_default = false
    where user_id = new.user_id and id <> new.id and is_default;
  end if;
  return new;
end $$;
drop trigger if exists addresses_single_default on public.addresses;
create trigger addresses_single_default after insert or update of is_default on public.addresses
  for each row when (new.is_default) execute function public.single_default_address();

do $$
declare t text;
begin
  foreach t in array array['cart_items', 'wishlist_items', 'library_entries', 'collections', 'addresses'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('drop policy if exists "%s: owner" on public.%I', t, t);
    execute format(
      'create policy "%s: owner" on public.%I for all using (user_id = auth.uid()) with check (user_id = auth.uid())',
      t, t);
  end loop;
end $$;

-- Reading progress + streak bookkeeping in one transaction (was a Firestore
-- transaction in firestore_library_repository.dart).
create or replace function public.update_reading_progress(
  p_book_id uuid,
  p_progress_percent numeric,
  p_current_chapter int
) -- DEFINER: users can't write streak columns directly (see profiles grants).
returns void language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
  v_now timestamptz := now();
  v_completing boolean := p_progress_percent >= 100;
  v_was_completed boolean;
  v_last_read timestamptz;
  v_streak int;
  v_longest int;
  v_days int;
begin
  if v_uid is null then
    raise exception 'not signed in';
  end if;

  select shelf = 'completed' into v_was_completed
  from library_entries where user_id = v_uid and book_id = p_book_id;
  v_was_completed := coalesce(v_was_completed, false);

  insert into library_entries (user_id, book_id, shelf, progress_percent, current_chapter, started_at, completed_at)
  values (
    v_uid, p_book_id,
    case when v_completing then 'completed' else 'currentlyReading' end,
    p_progress_percent, p_current_chapter, v_now,
    case when v_completing then v_now end
  )
  on conflict (user_id, book_id) do update set
    shelf = excluded.shelf,
    progress_percent = excluded.progress_percent,
    current_chapter = excluded.current_chapter,
    started_at = coalesce(library_entries.started_at, excluded.started_at),
    completed_at = case when v_completing then v_now else library_entries.completed_at end;

  select last_read_at, streak_count, longest_streak into v_last_read, v_streak, v_longest
  from profiles where id = v_uid for update;
  if not found then
    return;
  end if;

  if v_last_read is null then
    v_streak := 1;
  else
    v_days := v_now::date - v_last_read::date;
    if v_days = 1 then
      v_streak := v_streak + 1;
    elsif v_days > 1 then
      v_streak := 1;
    end if; -- same day: unchanged
  end if;

  update profiles set
    last_read_at = v_now,
    streak_count = v_streak,
    longest_streak = greatest(v_longest, v_streak),
    books_completed_count = books_completed_count
      + case when v_completing and not v_was_completed then 1 else 0 end
  where id = v_uid;
end $$;
revoke execute on function public.update_reading_progress(uuid, numeric, int) from public, anon;
grant execute on function public.update_reading_progress(uuid, numeric, int) to authenticated;

-- -----------------------------------------------------------------------------
-- Vouchers
-- -----------------------------------------------------------------------------

create table if not exists public.vouchers (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  title text not null default '',
  description text not null default '',
  discount_type text not null default 'percent' check (discount_type in ('percent', 'fixed')),
  discount_value numeric(10, 2) not null default 0,
  min_purchase numeric(10, 2) not null default 0,
  max_discount numeric(10, 2),
  expires_at timestamptz,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);
alter table public.vouchers enable row level security;
drop policy if exists "vouchers: public read" on public.vouchers;
create policy "vouchers: public read" on public.vouchers for select using (true);
drop policy if exists "vouchers: admin write" on public.vouchers;
create policy "vouchers: admin write" on public.vouchers for all
  using (public.is_admin()) with check (public.is_admin());

-- -----------------------------------------------------------------------------
-- Orders
-- -----------------------------------------------------------------------------

create table if not exists public.orders (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  items jsonb not null default '[]',
  subtotal numeric(10, 2) not null default 0,
  shipping_cost numeric(10, 2) not null default 0,
  voucher_code text,
  voucher_discount numeric(10, 2) not null default 0,
  total numeric(10, 2) not null default 0,
  shipping_address jsonb,
  shipping_option_id text not null default 'standard',
  status text not null default 'pending'
    check (status in ('pending', 'toShip', 'toReceive', 'completed', 'cancelled', 'failed')),
  payment_method text not null default 'cashOnDelivery'
    check (payment_method in ('gcash', 'maya', 'card', 'cashOnDelivery')),
  paymongo_reference_id text,
  rated boolean not null default false,
  created_at timestamptz not null default now(),
  paid_at timestamptz
);
create index if not exists orders_user_idx on public.orders (user_id, created_at desc);
-- Retrying a checkout with the same key returns the first order instead of
-- placing a second one.
alter table public.orders add column if not exists idempotency_key uuid;
create unique index if not exists orders_idempotency_idx on public.orders (user_id, idempotency_key);

-- A buyer may only ever flip `rated` on their own order; status changes are
-- admin-only (same as the old firestore.rules). INVOKER — see is_trusted.
create or replace function public.guard_order_update()
returns trigger language plpgsql set search_path = public as $$
begin
  if public.is_trusted() or public.is_admin() then
    return new;
  end if;
  if (to_jsonb(new) - 'rated') is distinct from (to_jsonb(old) - 'rated') then
    raise exception 'Only an admin can change this order';
  end if;
  return new;
end $$;
drop trigger if exists orders_guard_update on public.orders;
create trigger orders_guard_update before update on public.orders
  for each row execute function public.guard_order_update();

alter table public.orders enable row level security;
drop policy if exists "orders: read own or admin" on public.orders;
create policy "orders: read own or admin" on public.orders
  for select using (user_id = auth.uid() or public.is_admin());
-- Orders are created only by place_order(), which prices them from the
-- database. A direct insert could set its own prices, totals or paid_at.
drop policy if exists "orders: create own" on public.orders;
revoke insert, delete on public.orders from anon, authenticated;
drop policy if exists "orders: update own or admin" on public.orders;
create policy "orders: update own or admin" on public.orders
  for update using (user_id = auth.uid() or public.is_admin());

-- Placing an order takes items out of stock (failing if there aren't
-- enough); cancelling/failing it puts them back. The conditional UPDATE
-- locks the book row, so two buyers can't both take the last copy.
create or replace function public.apply_order_stock()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  item jsonb;
  v_qty int;
  v_title text;
  v_restock boolean;
begin
  if tg_op = 'INSERT' then
    for item in select * from jsonb_array_elements(new.items) loop
      v_qty := coalesce((item ->> 'quantity')::int, 1);
      if v_qty < 1 then
        raise exception 'Invalid quantity';
      end if;
      update books set stock = stock - v_qty
      where id = (item ->> 'bookId')::uuid and stock >= v_qty;
      if not found then
        select title into v_title from books where id = (item ->> 'bookId')::uuid;
        raise exception 'Out of stock: %', coalesce(v_title, item ->> 'title', 'an item in your cart')
          using errcode = 'P0001', hint = 'out_of_stock';
      end if;
    end loop;
    return new;
  end if;

  -- UPDATE: restock once when an order becomes cancelled/failed.
  v_restock := new.status in ('cancelled', 'failed') and old.status not in ('cancelled', 'failed');
  if v_restock then
    for item in select * from jsonb_array_elements(new.items) loop
      update books set stock = stock + coalesce((item ->> 'quantity')::int, 1)
      where id = (item ->> 'bookId')::uuid; -- a since-deleted product is simply skipped
    end loop;
    update seller_orders set status = 'cancelled' where order_id = new.id;
  end if;
  return new;
end $$;

drop trigger if exists orders_apply_stock_insert on public.orders;
create trigger orders_apply_stock_insert before insert on public.orders
  for each row execute function public.apply_order_stock();

drop trigger if exists orders_apply_stock_update on public.orders;
create trigger orders_apply_stock_update after update of status on public.orders
  for each row execute function public.apply_order_stock();

-- One fulfillment record per store in an order, so each seller ships their
-- own part. Sellers see their own records, never the buyer's whole order.
create table if not exists public.seller_orders (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders (id) on delete cascade,
  store_id uuid not null references public.stores (id) on delete restrict,
  status text not null default 'pending' check (status in
    ('pending', 'confirmed', 'processing', 'shipped', 'delivered', 'cancelled', 'refunded')),
  subtotal numeric(10, 2) not null,
  commission_total numeric(10, 2) not null,
  shipping_address jsonb,
  tracking_carrier text,
  tracking_number text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (order_id, store_id)
);
create index if not exists seller_orders_store_idx on public.seller_orders (store_id, created_at desc);
drop trigger if exists seller_orders_updated_at on public.seller_orders;
create trigger seller_orders_updated_at before update on public.seller_orders
  for each row execute function public.set_updated_at();

-- Price and commission are snapshotted at purchase, so later price or rate
-- changes never rewrite past earnings.
create table if not exists public.order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders (id) on delete cascade,
  seller_order_id uuid not null references public.seller_orders (id) on delete cascade,
  book_id uuid references public.books (id) on delete set null,
  title text not null,
  cover_url text not null default '',
  unit_price numeric(10, 2) not null check (unit_price >= 0),
  quantity int not null check (quantity between 1 and 99),
  commission_rate numeric(5, 4) not null check (commission_rate between 0 and 1),
  commission_amount numeric(10, 2) not null,
  created_at timestamptz not null default now()
);
create index if not exists order_items_order_idx on public.order_items (order_id);
create index if not exists order_items_seller_order_idx on public.order_items (seller_order_id);

alter table public.seller_orders enable row level security;
alter table public.order_items enable row level security;
revoke insert, update, delete on public.seller_orders, public.order_items from anon, authenticated;
drop policy if exists "seller_orders: buyer, store owner or admin" on public.seller_orders;
create policy "seller_orders: buyer, store owner or admin" on public.seller_orders for select using (
  exists (select 1 from public.orders o where o.id = order_id and o.user_id = auth.uid())
  or exists (select 1 from public.stores s where s.id = store_id and s.owner_id = auth.uid())
  or public.is_admin()
);
drop policy if exists "order_items: buyer, store owner or admin" on public.order_items;
create policy "order_items: buyer, store owner or admin" on public.order_items for select using (
  exists (select 1 from public.orders o where o.id = order_id and o.user_id = auth.uid())
  or exists (
    select 1 from public.seller_orders so join public.stores s on s.id = so.store_id
    where so.id = seller_order_id and s.owner_id = auth.uid())
  or public.is_admin()
);

-- Unpaid online orders give their stock back after 30 minutes, so nobody can
-- hold the catalog hostage. Runs at every checkout; schedule it with pg_cron
-- too if you want it to run while nobody is buying.
create or replace function public.expire_stale_orders()
returns int language plpgsql security definer set search_path = public as $$
declare
  v_count int;
begin
  update orders set status = 'failed'
  where status = 'pending' and created_at < now() - interval '30 minutes';
  get diagnostics v_count = row_count;
  return v_count;
end $$;
revoke execute on function public.expire_stale_orders() from public, anon, authenticated;

-- The only way to create an order. Everything that matters — prices, stock,
-- voucher, shipping fee, totals, commission — comes from the database; the
-- app only says what and how many.
--   p_items: [{"book_id": "<uuid>", "quantity": 2}, ...]
-- Returns {"id": <order id>, "total": <amount to pay>}.
create or replace function public.place_order(
  p_items jsonb,
  p_address_id uuid,
  p_shipping_option_id text,
  p_payment_method text,
  p_voucher_code text default null,
  p_idempotency_key uuid default null
) returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
  v_order_id uuid;
  v_total numeric(10, 2);
  v_address jsonb;
  v_lines jsonb;
  v_requested int;
  v_found int;
  v_subtotal numeric(10, 2);
  v_shipping numeric(10, 2);
  v_discount numeric(10, 2) := 0;
  v_voucher vouchers;
  v_default_rate numeric(5, 4);
begin
  if v_uid is null then
    raise exception 'You must be signed in.' using errcode = '42501';
  end if;

  if p_idempotency_key is not null then
    select id, total into v_order_id, v_total from orders
    where user_id = v_uid and idempotency_key = p_idempotency_key;
    if found then
      return jsonb_build_object('id', v_order_id, 'total', v_total);
    end if;
  end if;

  if p_payment_method not in ('gcash', 'maya', 'card', 'cashOnDelivery') then
    raise exception 'Unknown payment method.';
  end if;
  if p_shipping_option_id not in ('standard', 'express') then
    raise exception 'Unknown shipping option.';
  end if;
  if jsonb_typeof(p_items) is distinct from 'array' or jsonb_array_length(p_items) not between 1 and 50 then
    raise exception 'Your cart is empty.';
  end if;

  select jsonb_build_object(
    'label', label, 'recipientName', recipient_name, 'phoneNumber', phone_number,
    'addressLine', address_line, 'city', city, 'province', province, 'postalCode', postal_code)
  into v_address
  from addresses where id = p_address_id and user_id = v_uid;
  if v_address is null then
    raise exception 'Add a shipping address first.';
  end if;

  perform expire_stale_orders();

  select commission_rate into v_default_rate from platform_settings;

  -- Duplicate lines are merged; lines are sorted by book id so concurrent
  -- orders lock books in the same order (no deadlocks).
  with req as (
    select (e ->> 'book_id')::uuid as book_id, sum((e ->> 'quantity')::int) as qty
    from jsonb_array_elements(p_items) e
    group by 1
  )
  select
    (select count(*) from req),
    count(b.id),
    jsonb_agg(jsonb_build_object(
      'bookId', b.id, 'title', b.title, 'coverUrl', b.cover_url, 'unitPrice', b.price,
      'quantity', req.qty, 'storeId', b.store_id,
      'rate', coalesce(s.commission_rate, v_default_rate)) order by b.id),
    sum(b.price * req.qty)
  into v_requested, v_found, v_lines, v_subtotal
  from req
  join books b on b.id = req.book_id and b.listing_status = 'published'
  join stores s on s.id = b.store_id and s.status = 'active'
  where s.owner_id is distinct from v_uid;

  if v_found <> v_requested then
    raise exception 'Some items in your cart are no longer available.';
  end if;
  if exists (select 1 from jsonb_array_elements(v_lines) l where coalesce((l ->> 'quantity')::int, 0) not between 1 and 99) then
    raise exception 'Quantities must be between 1 and 99.';
  end if;

  -- Keep in sync with lib/core/models/shipping_option.dart.
  v_shipping := case
    when p_shipping_option_id = 'express' then 150
    when v_subtotal >= 1500 then 0
    else 60
  end;

  if nullif(trim(p_voucher_code), '') is not null then
    select * into v_voucher from vouchers where upper(code) = upper(trim(p_voucher_code));
    if not found or not v_voucher.is_active
       or (v_voucher.expires_at is not null and v_voucher.expires_at < now())
       or v_subtotal < v_voucher.min_purchase then
      raise exception 'Voucher % can''t be used on this order.', upper(trim(p_voucher_code))
        using hint = 'voucher_invalid';
    end if;
    -- Same rules as Voucher.discountFor in lib/core/models/voucher.dart.
    v_discount := case when v_voucher.discount_type = 'percent'
                       then round(v_subtotal * v_voucher.discount_value / 100, 2)
                       else v_voucher.discount_value end;
    if v_voucher.max_discount is not null then
      v_discount := least(v_discount, v_voucher.max_discount);
    end if;
    v_discount := greatest(least(v_discount, v_subtotal), 0);
  end if;

  v_total := greatest(v_subtotal + v_shipping - v_discount, 0);

  -- apply_order_stock takes the stock (or raises "Out of stock").
  insert into orders (user_id, items, subtotal, shipping_cost, voucher_code, voucher_discount, total,
                      shipping_address, shipping_option_id, status, payment_method, idempotency_key)
  values (
    v_uid,
    (select jsonb_agg(l - 'storeId' - 'rate') from jsonb_array_elements(v_lines) l),
    v_subtotal, v_shipping, v_voucher.code, v_discount, v_total,
    v_address, p_shipping_option_id,
    case when p_payment_method = 'cashOnDelivery' then 'toShip' else 'pending' end,
    p_payment_method, p_idempotency_key
  )
  returning id into v_order_id;

  insert into seller_orders (order_id, store_id, subtotal, commission_total, shipping_address)
  select v_order_id, (l ->> 'storeId')::uuid,
         sum((l ->> 'unitPrice')::numeric * (l ->> 'quantity')::int),
         sum(round((l ->> 'unitPrice')::numeric * (l ->> 'quantity')::int * (l ->> 'rate')::numeric, 2)),
         v_address
  from jsonb_array_elements(v_lines) l
  group by 2;

  insert into order_items (order_id, seller_order_id, book_id, title, cover_url, unit_price, quantity,
                           commission_rate, commission_amount)
  select v_order_id, so.id, (l ->> 'bookId')::uuid, l ->> 'title', l ->> 'coverUrl',
         (l ->> 'unitPrice')::numeric, (l ->> 'quantity')::int, (l ->> 'rate')::numeric,
         round((l ->> 'unitPrice')::numeric * (l ->> 'quantity')::int * (l ->> 'rate')::numeric, 2)
  from jsonb_array_elements(v_lines) l
  join seller_orders so on so.order_id = v_order_id and so.store_id = (l ->> 'storeId')::uuid;

  -- Sellers can't open the buyer's order itself, so no related_order_id.
  insert into notifications (user_id, category, title, body)
  select s.owner_id, 'orderUpdate', 'New order',
         'Order #' || upper(left(v_order_id::text, 8)) || ' has items from your store. See Seller Center → Orders.'
  from seller_orders so join stores s on s.id = so.store_id
  where so.order_id = v_order_id and s.owner_id is not null;

  return jsonb_build_object('id', v_order_id, 'total', v_total);
end $$;
revoke execute on function public.place_order(jsonb, uuid, text, text, text, uuid) from public, anon;
grant execute on function public.place_order(jsonb, uuid, text, text, text, uuid) to authenticated;

-- A seller moves their part of an order forward:
--   pending → confirmed → shipped (courier + tracking required) → delivered.
-- The buyer's order follows once every store has shipped / delivered.
create or replace function public.update_seller_order(
  p_seller_order_id uuid, p_status text, p_carrier text default null, p_tracking text default null
) returns void language plpgsql security definer set search_path = public as $$
declare
  so seller_orders;
  v_owner uuid;
  v_store_name text;
  v_order_status text;
  v_all_shipped boolean;
  v_all_delivered boolean;
begin
  select * into so from seller_orders where id = p_seller_order_id for update;
  if not found then
    raise exception 'Order not found';
  end if;
  select owner_id, name into v_owner, v_store_name from stores where id = so.store_id;
  if v_owner is distinct from auth.uid() and not public.is_admin() then
    raise exception 'This order belongs to another store' using errcode = '42501';
  end if;

  select status into v_order_status from orders where id = so.order_id for update;
  if v_order_status not in ('toShip', 'toReceive') then
    raise exception 'This order can''t be fulfilled right now (%).',
      case v_order_status when 'pending' then 'still awaiting payment' else v_order_status end;
  end if;

  if not ((so.status = 'pending' and p_status = 'confirmed')
       or (so.status in ('pending', 'confirmed') and p_status = 'shipped')
       or (so.status = 'shipped' and p_status = 'delivered')) then
    raise exception 'Can''t change this order from % to %.', so.status, p_status;
  end if;
  if p_status = 'shipped' and (coalesce(trim(p_carrier), '') = '' or coalesce(trim(p_tracking), '') = '') then
    raise exception 'Add the courier and tracking number.';
  end if;

  update seller_orders set
    status = p_status,
    tracking_carrier = coalesce(nullif(trim(p_carrier), ''), tracking_carrier),
    tracking_number = coalesce(nullif(trim(p_tracking), ''), tracking_number)
  where id = so.id;

  if p_status in ('shipped', 'delivered') then
    insert into notifications (user_id, category, title, body, related_order_id)
    select user_id, 'orderUpdate',
           case p_status when 'shipped' then 'Package shipped' else 'Package delivered' end,
           v_store_name || case p_status
             when 'shipped' then ' shipped your items via ' || trim(p_carrier) || ' (tracking ' || trim(p_tracking) || ').'
             else ' delivered your items.' end,
           id
    from orders where id = so.order_id;
  end if;

  select bool_and(status in ('shipped', 'delivered')), bool_and(status = 'delivered')
  into v_all_shipped, v_all_delivered
  from seller_orders where order_id = so.order_id and status <> 'cancelled';
  if v_all_delivered and v_order_status <> 'completed' then
    update orders set status = 'completed' where id = so.order_id;
  elsif v_all_shipped and v_order_status = 'toShip' then
    update orders set status = 'toReceive' where id = so.order_id;
  end if;
end $$;
revoke execute on function public.update_seller_order(uuid, text, text, text) from public, anon;

-- When an admin moves a whole order on (the Admin Panel's Orders screen),
-- every store's part follows, so seller views stay in step.
create or replace function public.sync_seller_orders_from_order()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.status = 'toReceive' then
    update seller_orders set status = 'shipped' where order_id = new.id and status in ('pending', 'confirmed');
  elsif new.status = 'completed' then
    update seller_orders set status = 'delivered'
    where order_id = new.id and status in ('pending', 'confirmed', 'shipped');
  end if;
  return null;
end $$;
drop trigger if exists orders_sync_seller_orders on public.orders;
create trigger orders_sync_seller_orders after update of status on public.orders
  for each row when (new.status is distinct from old.status)
  execute function public.sync_seller_orders_from_order();

-- -----------------------------------------------------------------------------
-- Reviews
-- -----------------------------------------------------------------------------

create table if not exists public.reviews (
  id uuid primary key default gen_random_uuid(),
  book_id uuid not null references public.books (id) on delete cascade,
  order_id uuid references public.orders (id) on delete set null,
  user_id uuid not null references auth.users (id) on delete cascade,
  user_name text not null default 'Reader',
  user_photo_url text,
  rating int not null check (rating between 1 and 5),
  text text not null default '',
  photo_url text,
  created_at timestamptz not null default now()
);
create index if not exists reviews_book_idx on public.reviews (book_id, created_at desc);
alter table public.reviews enable row level security;
drop policy if exists "reviews: public read" on public.reviews;
create policy "reviews: public read" on public.reviews for select using (true);
-- Only for a book in one of your own completed orders, once per order.
drop policy if exists "reviews: create own" on public.reviews;
create policy "reviews: create own" on public.reviews
  for insert with check (
    user_id = auth.uid()
    and exists (
      select 1 from public.orders o
      where o.id = order_id and o.user_id = auth.uid() and o.status = 'completed'
        and o.items @> jsonb_build_array(jsonb_build_object('bookId', book_id::text)))
    and not exists (
      select 1 from public.reviews r where r.order_id = reviews.order_id and r.book_id = reviews.book_id)
  );

-- The reviewer's name and photo come from their profile, not the request.
create or replace function public.fill_review_author()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  select coalesce(nullif(display_name, ''), 'Reader'), photo_url
  into new.user_name, new.user_photo_url
  from profiles where id = new.user_id;
  return new;
end $$;
drop trigger if exists reviews_fill_author on public.reviews;
create trigger reviews_fill_author before insert on public.reviews
  for each row execute function public.fill_review_author();

-- Running average, so seeded ratings and counts are kept, not reset.
create or replace function public.apply_review_rating()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  update books set
    rating = round((rating * rating_count + new.rating) / (rating_count + 1), 1),
    rating_count = rating_count + 1
  where id = new.book_id;
  return null;
end $$;
drop trigger if exists reviews_apply_rating on public.reviews;
create trigger reviews_apply_rating after insert on public.reviews
  for each row execute function public.apply_review_rating();

-- -----------------------------------------------------------------------------
-- Notifications
-- -----------------------------------------------------------------------------

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  category text not null default 'announcement' check (category in ('orderUpdate', 'announcement')),
  title text not null default '',
  body text not null default '',
  related_order_id uuid,
  read boolean not null default false,
  created_at timestamptz not null default now()
);
create index if not exists notifications_user_idx on public.notifications (user_id, created_at desc);
alter table public.notifications enable row level security;
drop policy if exists "notifications: read own" on public.notifications;
create policy "notifications: read own" on public.notifications
  for select using (user_id = auth.uid());
drop policy if exists "notifications: create own or admin" on public.notifications;
create policy "notifications: create own or admin" on public.notifications
  for insert with check (user_id = auth.uid() or public.is_admin());
drop policy if exists "notifications: mark read" on public.notifications;
create policy "notifications: mark read" on public.notifications
  for update using (user_id = auth.uid()) with check (user_id = auth.uid());
-- The owner may only ever change `read`.
revoke update on public.notifications from authenticated, anon;
grant update (read) on public.notifications to authenticated;

-- -----------------------------------------------------------------------------
-- Messages (one buyer <-> store thread per user)
-- -----------------------------------------------------------------------------

create or replace function public.notify_seller_on_message(
  p_store_id uuid,
  p_title text,
  p_body text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_owner uuid;
begin
  select owner_id into v_owner from public.stores where id = p_store_id;
  if v_owner is not null and v_owner <> auth.uid() then
    insert into public.notifications (user_id, category, title, body)
    values (v_owner, 'announcement', p_title, p_body);
  end if;
end;
$$;

revoke execute on function public.notify_seller_on_message(uuid, text, text) from public, anon;
grant execute on function public.notify_seller_on_message(uuid, text, text) to authenticated;

create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  sender text not null default 'user' check (sender in ('user', 'store')),
  text text not null,
  created_at timestamptz not null default now()
);
create index if not exists messages_user_idx on public.messages (user_id, created_at);
alter table public.messages enable row level security;
drop policy if exists "messages: read own or admin" on public.messages;
create policy "messages: read own or admin" on public.messages
  for select using (user_id = auth.uid() or public.is_admin());
-- Customers can only post as themselves, never as the store.
drop policy if exists "messages: create own or admin" on public.messages;
create policy "messages: create own or admin" on public.messages
  for insert with check ((user_id = auth.uid() and sender = 'user') or public.is_admin());

-- The canned greeting shown the first time someone opens their thread.
create or replace function public.send_store_welcome()
returns void language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then
    raise exception 'not signed in';
  end if;
  insert into messages (user_id, sender, text)
  select auth.uid(), 'store',
         'Hi! You''re messaging BookVerse Store. We usually reply within 24 hours — let us know if you need '
         'a hand with an order, a book request, or anything else.'
  where not exists (select 1 from messages where user_id = auth.uid());
end $$;
revoke execute on function public.send_store_welcome() from public, anon;
grant execute on function public.send_store_welcome() to authenticated;

-- The signup trigger inserts into notifications, so it's created last.
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.handle_new_user();

-- Backfill profiles for any accounts created before this trigger existed.
insert into public.profiles (id, email, display_name)
select id, coalesce(email, ''), coalesce(raw_user_meta_data ->> 'display_name', '')
from auth.users
on conflict (id) do nothing;

-- -----------------------------------------------------------------------------
-- Realtime: the app live-updates these tables (cart badge, orders, chat…)
-- -----------------------------------------------------------------------------

do $$
declare t text;
begin
  foreach t in array array[
    'profiles', 'books', 'cart_items', 'wishlist_items', 'library_entries', 'collections',
    'addresses', 'vouchers', 'orders', 'reviews', 'notifications', 'messages',
    'user_roles', 'stores', 'seller_applications', 'seller_orders'
  ] loop
    if not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = t
    ) then
      execute format('alter publication supabase_realtime add table public.%I', t);
    end if;
  end loop;
end $$;

-- -----------------------------------------------------------------------------
-- Storage: public image buckets (was Firebase Storage)
-- -----------------------------------------------------------------------------

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  ('avatars', 'avatars', true, 5242880, array['image/jpeg', 'image/png', 'image/webp', 'image/gif']),
  ('book-covers', 'book-covers', true, 5242880, array['image/jpeg', 'image/png', 'image/webp', 'image/gif']),
  ('review-photos', 'review-photos', true, 5242880, array['image/jpeg', 'image/png', 'image/webp', 'image/gif'])
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

-- Avatars: a user may only write files named "<their uid>.<ext>".
drop policy if exists "avatars: owner write" on storage.objects;
create policy "avatars: owner write" on storage.objects for all to authenticated
  using (bucket_id = 'avatars' and name like auth.uid()::text || '.%')
  with check (bucket_id = 'avatars' and name like auth.uid()::text || '.%');

-- Book covers: admins only (Firebase Storage couldn't check this; Postgres can).
drop policy if exists "book-covers: admin write" on storage.objects;
create policy "book-covers: admin write" on storage.objects for all to authenticated
  using (bucket_id = 'book-covers' and public.is_admin())
  with check (bucket_id = 'book-covers' and public.is_admin());

-- Sellers upload covers under a folder named after their store id.
drop policy if exists "book-covers: seller write" on storage.objects;
create policy "book-covers: seller write" on storage.objects for all to authenticated
  using (bucket_id = 'book-covers' and name like public.my_store_id()::text || '/%')
  with check (bucket_id = 'book-covers' and name like public.my_store_id()::text || '/%');

-- Review photos: any signed-in user, under a file name prefixed with their uid.
drop policy if exists "review-photos: owner write" on storage.objects;
create policy "review-photos: owner write" on storage.objects for all to authenticated
  using (bucket_id = 'review-photos' and name like auth.uid()::text || '\_%')
  with check (bucket_id = 'review-photos' and name like auth.uid()::text || '\_%');
