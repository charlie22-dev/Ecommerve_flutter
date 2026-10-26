-- Apply before deploying the updated payment Edge Functions and Flutter app.
-- Existing orders retain their recorded total and default tax_amount to zero.
begin;
alter table public.orders add column if not exists tax_amount numeric(10, 2) not null default 0 check (tax_amount >= 0);
alter table public.orders add column if not exists xendit_invoice_id text;
alter table public.orders add column if not exists xendit_invoice_url text;
alter table public.orders add column if not exists checkout_source text not null default 'unknown'
  check (checkout_source in ('unknown', 'cart', 'buyNow'));

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
  v_tax numeric(10, 2);
  v_discount numeric(10, 2) := 0;
  v_voucher vouchers;
  v_default_rate numeric(5, 4);
begin
  if v_uid is null then
    raise exception 'You must be signed in.' using errcode = '42501';
  end if;

  if p_idempotency_key is not null then
    perform pg_advisory_xact_lock(hashtextextended(v_uid::text || p_idempotency_key::text, 0));
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

  -- Business tax rate matches checkout_screen.dart. Historical receipts keep their original tax.
  v_tax := round(v_subtotal * 0.12, 2);
  v_total := greatest(v_subtotal + v_shipping + v_tax - v_discount, 0);

  -- apply_order_stock takes the stock (or raises "Out of stock").
  insert into orders (user_id, items, subtotal, shipping_cost, tax_amount, voucher_code, voucher_discount, total,
                      shipping_address, shipping_option_id, status, payment_method, idempotency_key, checkout_source)
  values (
    v_uid,
    (select jsonb_agg(l - 'storeId' - 'rate') from jsonb_array_elements(v_lines) l),
    v_subtotal, v_shipping, v_tax, v_voucher.code, v_discount, v_total,
    v_address, p_shipping_option_id,
    case when p_payment_method = 'cashOnDelivery' then 'toShip' else 'pending' end,
    p_payment_method, p_idempotency_key,
    case when p_items -> 0 ->> 'checkout_source' in ('cart', 'buyNow')
         then p_items -> 0 ->> 'checkout_source' else 'unknown' end
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


create or replace function public.sync_seller_orders_from_order()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.status = 'toShip' then
    update seller_orders set status = 'confirmed' where order_id = new.id and status = 'pending';
  elsif new.status = 'toReceive' then
    update seller_orders set status = 'shipped' where order_id = new.id and status in ('pending', 'confirmed');
  elsif new.status = 'completed' then
    update seller_orders set status = 'delivered'
    where order_id = new.id and status in ('pending', 'confirmed', 'shipped');
  end if;
  return null;
end $$;
-- Remove only quantities purchased from the cart. Direct Buy Now orders never
-- alter the cart. This runs in the same transaction as confirmation, so a
-- delayed callback works even if the shopper has closed the application.
create or replace function public.clear_purchased_cart_quantities()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  item jsonb;
  v_remaining int;
begin
  if new.checkout_source <> 'cart' or new.status <> 'toShip' then
    return null;
  end if;
  if tg_op = 'UPDATE' then
    if old.status <> 'pending' then return null; end if;
  end if;
  for item in select * from jsonb_array_elements(new.items) loop
    select quantity - (item ->> 'quantity')::int into v_remaining
    from cart_items where user_id = new.user_id and book_id = (item ->> 'bookId')::uuid
    for update;
    if found then
      if v_remaining <= 0 then
        delete from cart_items where user_id = new.user_id and book_id = (item ->> 'bookId')::uuid;
      else
        update cart_items set quantity = v_remaining
        where user_id = new.user_id and book_id = (item ->> 'bookId')::uuid;
      end if;
    end if;
  end loop;
  return null;
end $$;
revoke execute on function public.clear_purchased_cart_quantities() from public, anon, authenticated;
drop trigger if exists orders_clear_cart_insert on public.orders;
create trigger orders_clear_cart_insert after insert on public.orders
  for each row execute function public.clear_purchased_cart_quantities();
drop trigger if exists orders_clear_cart_update on public.orders;
create trigger orders_clear_cart_update after update of status on public.orders
  for each row when (new.status is distinct from old.status)
  execute function public.clear_purchased_cart_quantities();
commit;
