-- =============================================================================
-- BOOKVERSE: COMPLETE MESSAGING & PUSH NOTIFICATIONS MIGRATION
-- Run this in your Supabase SQL Editor (Dashboard -> SQL Editor -> New query -> Run)
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. CONVERSATIONS TABLE
-- -----------------------------------------------------------------------------
create table if not exists public.conversations (
  id uuid primary key default gen_random_uuid(),
  buyer_id uuid not null references auth.users (id) on delete cascade,
  store_id uuid not null references public.stores (id) on delete cascade,
  last_message text not null default '',
  last_message_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  unique (buyer_id, store_id)
);

create index if not exists conversations_buyer_idx on public.conversations (buyer_id, last_message_at desc);
create index if not exists conversations_store_idx on public.conversations (store_id, last_message_at desc);

-- PART 1 FIX: Store owner cannot message their own bookstore, and store must be approved
create or replace function public.check_conversation_parties()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_owner uuid;
  v_status text;
begin
  select owner_id, status into v_owner, v_status from public.stores where id = new.store_id;
  if not found then
    raise exception 'Store not found';
  end if;
  if v_status <> 'active' then
    raise exception 'Cannot message an unapproved or suspended store';
  end if;
  if v_owner is not null and v_owner = new.buyer_id then
    raise exception 'A store owner cannot start a conversation with their own store' using errcode = '23514';
  end if;
  return new;
end $$;

drop trigger if exists guard_conversation_buyer on public.conversations;
create trigger guard_conversation_buyer
before insert or update on public.conversations
for each row execute function public.check_conversation_parties();

-- -----------------------------------------------------------------------------
-- 2. MESSAGES TABLE
-- -----------------------------------------------------------------------------
drop table if exists public.messages cascade;

create table public.messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations (id) on delete cascade,
  sender_id uuid references auth.users (id) on delete set null,
  body text not null,
  type text not null default 'text' check (type in ('text', 'order', 'system')),
  order_id uuid references public.orders (id) on delete set null,
  is_read boolean not null default false,
  created_at timestamptz not null default now()
);

create index if not exists messages_conversation_idx on public.messages (conversation_id, created_at asc);
create index if not exists messages_created_at_idx on public.messages (created_at desc);
create index if not exists messages_order_idx on public.messages (order_id) where order_id is not null;

-- Trigger: keep conversation last_message and last_message_at in sync
create or replace function public.on_message_inserted()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  update public.conversations
  set last_message = new.body,
      last_message_at = new.created_at
  where id = new.conversation_id;
  return new;
end $$;

drop trigger if exists tr_on_message_inserted on public.messages;
create trigger tr_on_message_inserted
after insert on public.messages
for each row execute function public.on_message_inserted();

-- -----------------------------------------------------------------------------
-- 3. ROW LEVEL SECURITY (RLS) FOR CONVERSATIONS & MESSAGES
-- -----------------------------------------------------------------------------
alter table public.conversations enable row level security;
alter table public.messages enable row level security;

-- Conversations RLS
drop policy if exists "conversations: select" on public.conversations;
create policy "conversations: select" on public.conversations
  for select using (
    buyer_id = auth.uid()
    or exists (select 1 from public.stores s where s.id = store_id and s.owner_id = auth.uid())
    or public.is_admin()
  );

drop policy if exists "conversations: insert" on public.conversations;
create policy "conversations: insert" on public.conversations
  for insert with check (
    buyer_id = auth.uid()
    and exists (
      select 1 from public.stores s
      where s.id = store_id
        and s.status = 'active'
        and (s.owner_id is null or s.owner_id <> auth.uid())
    )
  );

drop policy if exists "conversations: update" on public.conversations;
create policy "conversations: update" on public.conversations
  for update using (
    buyer_id = auth.uid()
    or exists (select 1 from public.stores s where s.id = store_id and s.owner_id = auth.uid())
    or public.is_admin()
  );

-- Messages RLS
drop policy if exists "messages: select" on public.messages;
create policy "messages: select" on public.messages
  for select using (
    exists (
      select 1 from public.conversations c
      join public.stores s on s.id = c.store_id
      where c.id = conversation_id
        and (c.buyer_id = auth.uid() or s.owner_id = auth.uid() or public.is_admin())
    )
  );

drop policy if exists "messages: insert" on public.messages;
create policy "messages: insert" on public.messages
  for insert with check (
    sender_id = auth.uid()
    and exists (
      select 1 from public.conversations c
      join public.stores s on s.id = c.store_id
      where c.id = conversation_id
        and (c.buyer_id = auth.uid() or s.owner_id = auth.uid() or public.is_admin())
    )
  );

drop policy if exists "messages: update" on public.messages;
create policy "messages: update" on public.messages
  for update using (
    exists (
      select 1 from public.conversations c
      join public.stores s on s.id = c.store_id
      where c.id = conversation_id
        and (c.buyer_id = auth.uid() or s.owner_id = auth.uid() or public.is_admin())
    )
  );

-- Helper functions for client actions
create or replace function public.get_or_create_conversation(p_store_id uuid)
returns uuid language plpgsql security definer set search_path = public as $$
declare
  v_conv_id uuid;
  v_buyer_id uuid := auth.uid();
begin
  if v_buyer_id is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  select id into v_conv_id
  from public.conversations
  where buyer_id = v_buyer_id and store_id = p_store_id;

  if v_conv_id is null then
    insert into public.conversations (buyer_id, store_id)
    values (v_buyer_id, p_store_id)
    returning id into v_conv_id;
  end if;

  return v_conv_id;
end $$;

grant execute on function public.get_or_create_conversation(uuid) to authenticated;

create or replace function public.mark_conversation_read(p_conversation_id uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  update public.messages
  set is_read = true
  where conversation_id = p_conversation_id
    and is_read = false
    and (sender_id is null or sender_id <> auth.uid());
end $$;

grant execute on function public.mark_conversation_read(uuid) to authenticated;

-- -----------------------------------------------------------------------------
-- 4. SERVER-SIDE AUTOMATIC STORE MESSAGES FOR ORDERS (IDEMPOTENT TRIGGER)
-- -----------------------------------------------------------------------------
create or replace function public.handle_order_status_store_message()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  r record;
  v_conv_id uuid;
  v_body text;
  v_order_num text := upper(left(new.id::text, 8));
begin
  if TG_OP = 'INSERT' then
    v_body := 'Order #' || v_order_num || ' placed. We will process your order soon!';
  elsif TG_OP = 'UPDATE' then
    if old.status = new.status and old.paid_at is not distinct from new.paid_at then
      return new;
    end if;

    if (old.paid_at is null and new.paid_at is not null) or (old.status = 'pending' and new.status = 'toShip') then
      v_body := 'Payment received for Order #' || v_order_num || '. Preparing your shipment!';
    elsif new.status = 'toReceive' and old.status <> 'toReceive' then
      v_body := 'Order #' || v_order_num || ' has been shipped and is on the way!';
    elsif new.status = 'completed' and old.status <> 'completed' then
      v_body := 'Order #' || v_order_num || ' is completed. Thank you for reading with us!';
    elsif new.status = 'cancelled' and old.status <> 'cancelled' then
      v_body := 'Order #' || v_order_num || ' has been cancelled.';
    else
      return new;
    end if;
  end if;

  if v_body is null then
    return new;
  end if;

  -- Notify and message for each store in this order
  for r in
    select distinct s.id as store_id, s.owner_id
    from public.seller_orders so
    join public.stores s on s.id = so.store_id
    where so.order_id = new.id
  loop
    if r.owner_id is null or r.owner_id <> new.user_id then
      -- Get or create conversation between buyer and store
      select id into v_conv_id
      from public.conversations
      where buyer_id = new.user_id and store_id = r.store_id;

      if v_conv_id is null then
        insert into public.conversations (buyer_id, store_id, last_message, last_message_at)
        values (new.user_id, r.store_id, v_body, now())
        on conflict (buyer_id, store_id) do update set
          last_message = excluded.last_message,
          last_message_at = excluded.last_message_at
        returning id into v_conv_id;

        if v_conv_id is null then
          select id into v_conv_id
          from public.conversations
          where buyer_id = new.user_id and store_id = r.store_id;
        end if;
      end if;

      -- Idempotent check
      if v_conv_id is not null and not exists (
        select 1 from public.messages
        where conversation_id = v_conv_id
          and order_id = new.id
          and body = v_body
      ) then
        insert into public.messages (conversation_id, sender_id, body, type, order_id, is_read)
        values (v_conv_id, r.owner_id, v_body, 'order', new.id, false);
      end if;
    end if;
  end loop;

  return new;
end $$;

drop trigger if exists tr_order_status_store_message on public.orders;
create trigger tr_order_status_store_message
after insert or update on public.orders
for each row execute function public.handle_order_status_store_message();

-- -----------------------------------------------------------------------------
-- 5. DEVICE TOKENS TABLE FOR PUSH NOTIFICATIONS
-- -----------------------------------------------------------------------------
create table if not exists public.device_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  fcm_token text not null unique,
  platform text not null default 'android',
  updated_at timestamptz not null default now()
);

create index if not exists device_tokens_user_idx on public.device_tokens (user_id);
alter table public.device_tokens enable row level security;

drop policy if exists "device_tokens: own manage" on public.device_tokens;
create policy "device_tokens: own manage" on public.device_tokens
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());

-- Upsert device token helper
create or replace function public.register_device_token(p_token text, p_platform text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then
    return;
  end if;
  insert into public.device_tokens (user_id, fcm_token, platform, updated_at)
  values (auth.uid(), p_token, p_platform, now())
  on conflict (fcm_token) do update
  set user_id = auth.uid(),
      platform = excluded.platform,
      updated_at = now();
end $$;

grant execute on function public.register_device_token(text, text) to authenticated;

-- -----------------------------------------------------------------------------
-- 6. IN-APP NOTIFICATIONS TABLE SCHEMA ALIGNMENT
-- -----------------------------------------------------------------------------
alter table public.notifications add column if not exists type text default 'general';
alter table public.notifications add column if not exists data jsonb default '{}'::jsonb;
alter table public.notifications add column if not exists is_read boolean default false;

-- Sync helper for backward compatibility
create or replace function public.sync_notification_cols()
returns trigger language plpgsql as $$
begin
  if new.is_read is distinct from old.is_read then
    new.read := new.is_read;
  elsif new.read is distinct from old.read then
    new.is_read := new.read;
  end if;
  if new.type is null and new.category is not null then
    new.type := new.category;
  end if;
  return new;
end $$;

drop trigger if exists tr_sync_notification_cols on public.notifications;
create trigger tr_sync_notification_cols
before insert or update on public.notifications
for each row execute function public.sync_notification_cols();

-- -----------------------------------------------------------------------------
-- 7. ENABLE SUPABASE REALTIME
-- -----------------------------------------------------------------------------
do $$
begin
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and tablename = 'conversations') then
    alter publication supabase_realtime add table public.conversations;
  end if;
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and tablename = 'messages') then
    alter publication supabase_realtime add table public.messages;
  end if;
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and tablename = 'notifications') then
    alter publication supabase_realtime add table public.notifications;
  end if;
end $$;
