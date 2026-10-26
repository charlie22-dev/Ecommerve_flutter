-- Run on a disposable Supabase database after current schema/migrations.
-- Transaction tests only: no real provider charge is made.
begin;
do $$
declare
  v_uid uuid := gen_random_uuid();
  v_book uuid := gen_random_uuid();
  v_address uuid := gen_random_uuid();
  v_key uuid := gen_random_uuid();
  v_order jsonb;
  v_retry jsonb;
  v_total numeric;
  v_tax numeric;
begin
  insert into auth.users (id, email) values (v_uid, v_uid::text || '@payment-test.invalid');
  insert into public.addresses (id, user_id, recipient_name, address_line, city)
  values (v_address, v_uid, 'Test buyer', '1 Test Street', 'Cebu');
  insert into public.books (id, title, type, price, stock)
  values (v_book, 'Payment fixture', 'manga', 250, 20);
  insert into public.cart_items (user_id, book_id, quantity) values (v_uid, v_book, 5);
  perform set_config('request.jwt.claims', jsonb_build_object('sub', v_uid)::text, true);

  v_order := public.place_order(jsonb_build_array(jsonb_build_object(
    'book_id', v_book, 'quantity', 2, 'checkout_source', 'cart')),
    v_address, 'standard', 'cashOnDelivery', null, v_key);
  select total, tax_amount into v_total, v_tax from public.orders where id = (v_order ->> 'id')::uuid;
  assert v_total = 620 and v_tax = 60, 'COD must record shipping plus rounded tax';
  assert (v_order ->> 'total')::numeric = v_total, 'RPC and saved totals must agree';
  assert (select quantity from public.cart_items where user_id = v_uid and book_id = v_book) = 3,
    'COD removes only the purchased quantities';

  v_retry := public.place_order(jsonb_build_array(jsonb_build_object(
    'book_id', v_book, 'quantity', 2, 'checkout_source', 'cart')),
    v_address, 'standard', 'cashOnDelivery', null, v_key);
  assert v_order ->> 'id' = v_retry ->> 'id', 'Retry must return the existing order';
  assert (select quantity from public.cart_items where user_id = v_uid and book_id = v_book) = 3,
    'Retry must not remove more cart quantities';

  v_order := public.place_order(jsonb_build_array(jsonb_build_object(
    'book_id', v_book, 'quantity', 2, 'checkout_source', 'cart')),
    v_address, 'standard', 'gcash');
  assert (v_order ->> 'total')::numeric = 620, 'Online and COD totals must agree';
  assert (select quantity from public.cart_items where user_id = v_uid and book_id = v_book) = 3,
    'Pending payment keeps the cart';
  -- Simulate the trusted server recording a verified payment.
  update public.orders set status = 'toShip', paid_at = now() where id = (v_order ->> 'id')::uuid;
  assert (select quantity from public.cart_items where user_id = v_uid and book_id = v_book) = 1,
    'Confirmed payment removes purchased quantities';
  update public.orders set status = 'toShip' where id = (v_order ->> 'id')::uuid;
  assert (select quantity from public.cart_items where user_id = v_uid and book_id = v_book) = 1,
    'Repeated confirmation must not clear the cart again';
  assert not exists (select 1 from public.seller_orders
    where order_id = (v_order ->> 'id')::uuid and status <> 'confirmed'),
    'Payment confirmation must update seller fulfillment';

  perform public.place_order(jsonb_build_array(jsonb_build_object(
    'book_id', v_book, 'quantity', 1, 'checkout_source', 'buyNow')),
    v_address, 'standard', 'cashOnDelivery');
  assert (select quantity from public.cart_items where user_id = v_uid and book_id = v_book) = 1,
    'Buy Now must leave existing cart quantities alone';
  raise notice 'PAYMENT CONSISTENCY TESTS PASSED';
end $$;
rollback;
