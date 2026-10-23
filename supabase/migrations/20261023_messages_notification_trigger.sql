-- =============================================================================
-- BOOKVERSE: NOTIFICATION TRIGGER FOR CHAT MESSAGES (PURE SUPABASE)
-- Run this in your Supabase SQL Editor (Dashboard -> SQL Editor -> New query -> Run)
-- =============================================================================

create or replace function public.notify_on_new_message()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_buyer_id uuid;
  v_store_id uuid;
  v_owner_id uuid;
  v_is_official boolean;
  v_store_name text;
  v_sender_name text;
begin
  -- Look up conversation and store info
  select c.buyer_id, c.store_id, s.owner_id, s.is_official, s.name
  into v_buyer_id, v_store_id, v_owner_id, v_is_official, v_store_name
  from public.conversations c
  join public.stores s on s.id = c.store_id
  where c.id = new.conversation_id;

  if not found then
    return new;
  end if;

  -- Get sender display name
  select coalesce(display_name, 'Someone') into v_sender_name
  from public.profiles
  where id = new.sender_id;

  -- Determine who to notify
  if new.sender_id = v_buyer_id then
    -- Buyer sent message -> notify store owner (or admins if official store)
    if v_owner_id is not null then
      insert into public.notifications (user_id, category, title, body)
      values (v_owner_id, 'announcement', 'New message from ' || v_sender_name, new.body);
    elsif v_is_official then
      -- Notify all platform admins
      insert into public.notifications (user_id, category, title, body)
      select p.id, 'announcement', 'New BookVerse Support message from ' || v_sender_name, new.body
      from public.profiles p
      where p.is_admin = true and p.id <> new.sender_id;
    end if;
  else
    -- Store owner or Admin replied -> notify the buyer
    insert into public.notifications (user_id, category, title, body)
    values (v_buyer_id, 'announcement', coalesce(v_store_name, 'BookVerse Store'), new.body);
  end if;

  return new;
end;
$$;

drop trigger if exists tr_notify_on_new_message on public.messages;
create trigger tr_notify_on_new_message
after insert on public.messages
for each row execute function public.notify_on_new_message();
