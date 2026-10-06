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
  is_admin boolean not null default false,
  created_at timestamptz not null default now()
);

-- SECURITY DEFINER so policies can call it without recursing into the
-- profiles RLS policy itself.
create or replace function public.is_admin()
returns boolean language sql stable security definer set search_path = public as $$
  select coalesce((select is_admin from public.profiles where id = auth.uid()), false);
$$;

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

-- Only an existing admin (or you, from the SQL editor / service role, where
-- auth.uid() is null) can change is_admin. A normal user flipping it on
-- their own row is silently ignored.
create or replace function public.guard_profile_admin_flag()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.is_admin is distinct from old.is_admin
     and auth.uid() is not null
     and not public.is_admin() then
    new.is_admin := old.is_admin;
  end if;
  return new;
end $$;

drop trigger if exists profiles_guard_admin on public.profiles;
create trigger profiles_guard_admin before update on public.profiles
  for each row execute function public.guard_profile_admin_flag();

alter table public.profiles enable row level security;
drop policy if exists "profiles: read own" on public.profiles;
create policy "profiles: read own" on public.profiles
  for select using (id = auth.uid() or public.is_admin());
drop policy if exists "profiles: update own" on public.profiles;
create policy "profiles: update own" on public.profiles
  for update using (id = auth.uid()) with check (id = auth.uid());

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

alter table public.books enable row level security;
drop policy if exists "books: public read" on public.books;
create policy "books: public read" on public.books for select using (true);
drop policy if exists "books: admin write" on public.books;
create policy "books: admin write" on public.books for all
  using (public.is_admin()) with check (public.is_admin());

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
) returns void language plpgsql security invoker set search_path = public as $$
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

-- A buyer may only ever flip `rated` on their own order; status changes are
-- admin-only (same as the old firestore.rules).
create or replace function public.guard_order_update()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null or public.is_admin() then
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
drop policy if exists "orders: create own" on public.orders;
create policy "orders: create own" on public.orders
  for insert with check (user_id = auth.uid() and status in ('pending', 'toShip'));
drop policy if exists "orders: update own or admin" on public.orders;
create policy "orders: update own or admin" on public.orders
  for update using (user_id = auth.uid() or public.is_admin());

-- Placing an order takes items out of stock (failing if there aren't
-- enough); cancelling/failing it puts them back. See also 002_stock.sql.
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
  end if;
  return new;
end $$;

drop trigger if exists orders_apply_stock_insert on public.orders;
create trigger orders_apply_stock_insert before insert on public.orders
  for each row execute function public.apply_order_stock();

drop trigger if exists orders_apply_stock_update on public.orders;
create trigger orders_apply_stock_update after update of status on public.orders
  for each row execute function public.apply_order_stock();

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
drop policy if exists "reviews: create own" on public.reviews;
create policy "reviews: create own" on public.reviews
  for insert with check (user_id = auth.uid());

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
drop policy if exists "messages: create own or admin" on public.messages;
create policy "messages: create own or admin" on public.messages
  for insert with check (user_id = auth.uid() or public.is_admin());

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
    'addresses', 'vouchers', 'orders', 'reviews', 'notifications', 'messages'
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

-- Review photos: any signed-in user, under a file name prefixed with their uid.
drop policy if exists "review-photos: owner write" on storage.objects;
create policy "review-photos: owner write" on storage.objects for all to authenticated
  using (bucket_id = 'review-photos' and name like auth.uid()::text || '\_%')
  with check (bucket_id = 'review-photos' and name like auth.uid()::text || '\_%');
