-- =============================================================================
-- BookVerse — marketplace security tests (roles, RLS, checkout)
--
-- Run AFTER schema.sql (and seed.sql) in SQL Editor → New query → paste → Run.
-- Everything happens inside one transaction that is rolled back at the end,
-- so it leaves no data behind. Success = "ALL MARKETPLACE TESTS PASSED" in the
-- output; any failing check stops the script with its message.
--
-- Each block "logs in" by setting the JWT claims + role the way PostgREST
-- does for a real app request, so RLS and grants apply exactly as they would
-- for the Flutter app.
-- =============================================================================

begin;

-- ---------------------------------------------------------------- fixtures --
insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-0000000000a1', 'admin@test.dev'),
  ('00000000-0000-0000-0000-0000000000c1', 'cust1@test.dev'),
  ('00000000-0000-0000-0000-0000000000c2', 'cust2@test.dev'),
  ('00000000-0000-0000-0000-0000000000b1', 'seller1@test.dev'),
  ('00000000-0000-0000-0000-0000000000b2', 'seller2@test.dev');
insert into public.user_roles (user_id, role) values ('00000000-0000-0000-0000-0000000000a1', 'super_admin');
update public.profiles set display_name = 'Cust One' where id = '00000000-0000-0000-0000-0000000000c1';
insert into public.addresses (id, user_id, recipient_name, address_line, city) values
  ('00000000-0000-0000-0000-00000000ad01', '00000000-0000-0000-0000-0000000000c1', 'Cust One', '1 Main St', 'Cebu'),
  ('00000000-0000-0000-0000-00000000ad02', '00000000-0000-0000-0000-0000000000c2', 'Cust Two', '2 Main St', 'Cebu');
-- Two official books with known price/stock.
insert into public.books (id, title, price, stock) values
  ('00000000-0000-0000-0000-0000000b0001', 'Test Book One', 100, 1),
  ('00000000-0000-0000-0000-0000000b0002', 'Test Book Two', 250, 10);
insert into public.vouchers (code, discount_type, discount_value, min_purchase, is_active, expires_at) values
  ('TEST10', 'percent', 10, 0, true, null),
  ('TESTOLD', 'fixed', 50, 0, true, now() - interval '1 day');
update public.platform_settings set commission_rate = 0.10;

-- ------------------------------------------- 1. anonymous visitors can browse --
set local role anon;
select set_config('request.jwt.claims', '', true);
do $$ begin
  assert (select count(*) from public.books where id = '00000000-0000-0000-0000-0000000b0001') = 1,
    '1: anon should see published books';
  begin
    perform public.place_order('[]', null, 'standard', 'cashOnDelivery');
    raise exception 'FAIL 1: anon placed an order';
  exception when others then
    if sqlerrm like 'FAIL%' then raise; end if;
  end;
end $$;

-- ------------------------------ 3. a customer cannot make themselves admin --
reset role;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000c1"}', true);
set local role authenticated;
do $$ begin
  begin
    insert into public.user_roles (user_id, role) values (auth.uid(), 'admin');
    raise exception 'FAIL 3: customer inserted a role';
  exception when others then if sqlerrm like 'FAIL%' then raise; end if; end;
  begin
    update public.profiles set is_admin = true where id = auth.uid();
    raise exception 'FAIL 3: customer set is_admin';
  exception when others then if sqlerrm like 'FAIL%' then raise; end if; end;
  begin
    update public.profiles set streak_count = 999 where id = auth.uid();
    raise exception 'FAIL 3: customer faked their streak';
  exception when others then if sqlerrm like 'FAIL%' then raise; end if; end;
  begin
    perform public.set_user_role(auth.uid(), 'super_admin', true);
    raise exception 'FAIL 3: customer called set_user_role';
  exception when others then if sqlerrm like 'FAIL%' then raise; end if; end;
  assert not public.is_admin(), '3: customer is admin';
  -- Name edits still work.
  update public.profiles set display_name = 'Cust 1' where id = auth.uid();
  assert (select display_name from public.profiles where id = auth.uid()) = 'Cust 1', '3: name edit blocked';
end $$;

-- ------------------------ 8. prices, totals and vouchers come from the server --
do $$
declare r jsonb; o record;
begin
  begin
    insert into public.orders (user_id, items, subtotal, total, status)
    values (auth.uid(), '[]', 0, 0, 'toShip');
    raise exception 'FAIL 8: direct order insert allowed';
  exception when others then if sqlerrm like 'FAIL%' then raise; end if; end;

  -- A tampered unitPrice in the request is ignored.
  r := public.place_order(
    '[{"book_id":"00000000-0000-0000-0000-0000000b0002","quantity":2,"unitPrice":0}]',
    '00000000-0000-0000-0000-00000000ad01', 'standard', 'cashOnDelivery', 'test10');
  select * into o from public.orders where id = (r ->> 'id')::uuid;
  assert o.subtotal = 500 and o.voucher_discount = 50 and o.shipping_cost = 60 and o.total = 510,
    format('8: wrong totals %s/%s/%s/%s', o.subtotal, o.voucher_discount, o.shipping_cost, o.total);
  assert (r ->> 'total')::numeric = 510, '8: wrong returned total';
  assert o.status = 'toShip', '8: COD order should be toShip';

  begin
    perform public.place_order('[{"book_id":"00000000-0000-0000-0000-0000000b0002","quantity":1}]',
      '00000000-0000-0000-0000-00000000ad01', 'standard', 'cashOnDelivery', 'TESTOLD');
    raise exception 'FAIL 8: expired voucher accepted';
  exception when others then if sqlerrm like 'FAIL%' then raise; end if; end;

  begin
    perform public.place_order('[{"book_id":"00000000-0000-0000-0000-0000000b0002","quantity":-5}]',
      '00000000-0000-0000-0000-00000000ad01', 'standard', 'cashOnDelivery');
    raise exception 'FAIL 8: negative quantity accepted';
  exception when others then if sqlerrm like 'FAIL%' then raise; end if; end;

  begin
    perform public.place_order('[{"book_id":"00000000-0000-0000-0000-0000000b0002","quantity":1}]',
      '00000000-0000-0000-0000-00000000ad02', 'standard', 'cashOnDelivery');
    raise exception 'FAIL 8: used someone else''s address';
  exception when others then if sqlerrm like 'FAIL%' then raise; end if; end;
end $$;

-- ------------------------------------------------------- 13. idempotency --
do $$
declare r1 jsonb; r2 jsonb; n int;
begin
  select count(*) into n from public.orders where user_id = auth.uid();
  r1 := public.place_order('[{"book_id":"00000000-0000-0000-0000-0000000b0002","quantity":1}]',
    '00000000-0000-0000-0000-00000000ad01', 'standard', 'cashOnDelivery', null,
    '00000000-0000-0000-0000-0000000001de');
  r2 := public.place_order('[{"book_id":"00000000-0000-0000-0000-0000000b0002","quantity":1}]',
    '00000000-0000-0000-0000-00000000ad01', 'standard', 'cashOnDelivery', null,
    '00000000-0000-0000-0000-0000000001de');
  assert r1 ->> 'id' = r2 ->> 'id', '13: retry created a second order';
  assert (select count(*) from public.orders where user_id = auth.uid()) = n + 1, '13: duplicate order';
end $$;

-- ------------------------------- 7. the last unit can't be sold twice --
do $$ begin
  begin
    perform public.place_order('[{"book_id":"00000000-0000-0000-0000-0000000b0001","quantity":2}]',
      '00000000-0000-0000-0000-00000000ad01', 'standard', 'cashOnDelivery');
    raise exception 'FAIL 7: sold 2 of a book with stock 1';
  exception when others then if sqlerrm like 'FAIL%' then raise; end if; end;
  perform public.place_order('[{"book_id":"00000000-0000-0000-0000-0000000b0001","quantity":1}]',
    '00000000-0000-0000-0000-00000000ad01', 'standard', 'cashOnDelivery');
end $$;

reset role; 
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000c2"}', true);
set local role authenticated;
do $$ begin
  begin
    perform public.place_order('[{"book_id":"00000000-0000-0000-0000-0000000b0001","quantity":1}]',
      '00000000-0000-0000-0000-00000000ad02', 'standard', 'cashOnDelivery');
    raise exception 'FAIL 7: second buyer got the last unit';
  exception when others then if sqlerrm like 'FAIL%' then raise; end if; end;
  assert (select stock from public.books where id = '00000000-0000-0000-0000-0000000b0001') = 0,
    '7: stock should be exactly 0';

  -- 2. customers can't see each other's orders.
  assert (select count(*) from public.orders
          where user_id = '00000000-0000-0000-0000-0000000000c1') = 0, '2: saw another customer''s orders';
  assert (select count(*) from public.seller_orders) = 0, '2: saw another customer''s seller orders';
  assert (select count(*) from public.order_items) = 0, '2: saw another customer''s order items';
end $$;

-- ------------------------------- 4. seller applications need approval --
reset role;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000b1"}', true);
set local role authenticated;
do $$ begin
  begin
    insert into public.seller_applications (user_id, store_name, status)
    values (auth.uid(), 'Sneaky Store', 'approved');
    raise exception 'FAIL 4: applied as already approved';
  exception when others then if sqlerrm like 'FAIL%' then raise; end if; end;

  insert into public.seller_applications (user_id, store_name) values (auth.uid(), 'Manga Corner');

  begin
    insert into public.books (title, price, stock, type, store_id)
    values ('Too early', 10, 1, 'book', (select id from public.stores where is_official));
    raise exception 'FAIL 4: listed a product before approval';
  exception when others then if sqlerrm like 'FAIL%' then raise; end if; end;
  begin
    perform public.review_seller_application(
      (select id from public.seller_applications where user_id = auth.uid()), true);
    raise exception 'FAIL 4: approved own application';
  exception when others then if sqlerrm like 'FAIL%' then raise; end if; end;
  begin
    update public.seller_applications set status = 'approved' where user_id = auth.uid();
    raise exception 'FAIL 4: applicant approved their own application';
  exception when others then if sqlerrm like 'FAIL%' then raise; end if; end;
end $$;

reset role;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000b2"}', true);
set local role authenticated;
insert into public.seller_applications (user_id, store_name) values (auth.uid(), 'Comic Vault');

-- Admin approves both (and checks the audit log).
reset role;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000a1"}', true);
set local role authenticated;
do $$ begin
  begin
    insert into public.seller_applications (user_id, store_name) values (auth.uid(), 'Admin Store');
    raise exception 'FAIL 4: an admin applied to be a seller';
  exception when others then if sqlerrm like 'FAIL%' then raise; end if; end;
  begin
    perform public.review_seller_application(
      (select id from public.seller_applications where user_id = '00000000-0000-0000-0000-0000000000b2'), false, '');
    raise exception 'FAIL 4: rejected without a reason';
  exception when others then if sqlerrm like 'FAIL%' then raise; end if; end;
  perform public.review_seller_application(id, true, 'Welcome') from public.seller_applications
  where status = 'pending' and user_id in ('00000000-0000-0000-0000-0000000000b1', '00000000-0000-0000-0000-0000000000b2');
  assert (select count(*) from public.stores where owner_id in
          ('00000000-0000-0000-0000-0000000000b1', '00000000-0000-0000-0000-0000000000b2')) = 2,
    '4: approval did not create stores';
  assert (select count(*) from public.admin_audit_logs where action = 'seller.approve') >= 2,
    '4: approvals not audited';
end $$;

-- --------------------- 6. sellers list products, but only admins publish --
reset role;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000b1"}', true);
set local role authenticated;
do $$ begin
  insert into public.books (id, title, price, stock, type, store_id, listing_status, rating, featured_sections)
  values ('00000000-0000-0000-0000-0000000b0003', 'Seller One Manga', 300, 5, 'manga',
          public.my_store_id(), 'published', 5, '{trending}');
  assert (select listing_status from public.books where id = '00000000-0000-0000-0000-0000000b0003')
    = 'pending_review', '6: seller self-published on insert';
  assert (select rating from public.books where id = '00000000-0000-0000-0000-0000000b0003') = 0,
    '6: seller set their own rating';
  begin
    update public.books set listing_status = 'published' where id = '00000000-0000-0000-0000-0000000b0003';
    raise exception 'FAIL 6: seller published a pending listing';
  exception when others then if sqlerrm like 'FAIL%' then raise; end if; end;
  begin
    insert into public.books (title, price, stock, type, store_id)
    values ('Wrong store', 10, 1, 'book', (select id from public.stores where is_official));
    raise exception 'FAIL 6: seller listed into another store';
  exception when others then if sqlerrm like 'FAIL%' then raise; end if; end;
  -- Rule: books only.
  begin
    insert into public.books (title, price, stock, type) values ('Anime Keychain', 99, 10, 'other');
    raise exception 'FAIL: seller listed a non-book item';
  exception when others then if sqlerrm like 'FAIL%' then raise; end if; end;
  begin
    update public.books set type = 'other' where id = '00000000-0000-0000-0000-0000000b0003';
    raise exception 'FAIL: seller changed a listing into a non-book item';
  exception when others then if sqlerrm like 'FAIL%' then raise; end if; end;
  -- No store_id given: the listing goes into the seller's own store.
  insert into public.books (title, price, stock, type) values ('Seller One Novel', 120, 2, 'novel');
  assert (select store_id from public.books where title = 'Seller One Novel') = public.my_store_id(),
    '6: listing without store_id not put in seller''s store';
  begin
    perform public.moderate_listing('00000000-0000-0000-0000-0000000b0003', 'published');
    raise exception 'FAIL 11: seller moderated a listing';
  exception when others then if sqlerrm like 'FAIL%' then raise; end if; end;
  -- Seller can still edit their own listing.
  update public.books set stock = 6 where id = '00000000-0000-0000-0000-0000000b0003';
  assert (select stock from public.books where id = '00000000-0000-0000-0000-0000000b0003') = 6,
    '6: seller could not edit own listing';
end $$;

-- 5. another seller can't touch it (RLS hides the row, so nothing changes).
reset role;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000b2"}', true);
set local role authenticated;
do $$ begin
  update public.books set price = 1 where id = '00000000-0000-0000-0000-0000000b0003';
  update public.books set price = 1 where id = '00000000-0000-0000-0000-0000000b0002';
  assert (select count(*) from public.books where id = '00000000-0000-0000-0000-0000000b0003') = 0,
    '5: other seller can see an unpublished listing';
end $$;
reset role;
do $$ begin
  assert (select price from public.books where id = '00000000-0000-0000-0000-0000000b0003') = 300,
    '5: another seller changed the price';
  assert (select price from public.books where id = '00000000-0000-0000-0000-0000000b0002') = 250,
    '5: a seller changed an official book';
end $$;

-- Unpublished listings are hidden from shoppers and can't be bought.
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000c1"}', true);
set local role authenticated;
do $$ begin
  assert (select count(*) from public.books where id = '00000000-0000-0000-0000-0000000b0003') = 0,
    '6: shopper sees a pending listing';
  begin
    perform public.place_order('[{"book_id":"00000000-0000-0000-0000-0000000b0003","quantity":1}]',
      '00000000-0000-0000-0000-00000000ad01', 'standard', 'cashOnDelivery');
    raise exception 'FAIL 6: bought a pending listing';
  exception when others then if sqlerrm like 'FAIL%' then raise; end if; end;
end $$;

-- 11. admin moderates.
reset role;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000a1"}', true);
set local role authenticated;
select public.moderate_listing('00000000-0000-0000-0000-0000000b0003', 'published');

-- ------------------- 9/12. multi-seller order split + commission snapshot --
reset role;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000c1"}', true);
set local role authenticated;
do $$
declare r jsonb;
begin
  r := public.place_order(
    '[{"book_id":"00000000-0000-0000-0000-0000000b0003","quantity":1},'
    ' {"book_id":"00000000-0000-0000-0000-0000000b0002","quantity":2}]',
    '00000000-0000-0000-0000-00000000ad01', 'standard', 'cashOnDelivery');
  perform set_config('test.split_order', r ->> 'id', true);
  assert (select count(*) from public.seller_orders where order_id = (r ->> 'id')::uuid) = 2,
    '9: order not split per seller';
  assert (select count(*) from public.order_items where order_id = (r ->> 'id')::uuid) = 2,
    '9: missing order items';
  assert (select commission_amount from public.order_items
          where order_id = (r ->> 'id')::uuid and book_id = '00000000-0000-0000-0000-0000000b0003') = 30,
    '12: wrong commission';
end $$;

reset role;
update public.platform_settings set commission_rate = 0.25;
do $$ begin
  assert (select commission_rate from public.order_items
          where order_id = current_setting('test.split_order')::uuid
            and book_id = '00000000-0000-0000-0000-0000000b0003') = 0.10,
    '12: rate change rewrote a past order';
end $$;

-- 10. sellers see only their own part of the order.
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000b1"}', true);
set local role authenticated;
do $$ begin
  assert (select count(*) from public.seller_orders) = 1, '10: seller sees other stores'' records';
  assert (select count(*) from public.order_items) = 1, '10: seller sees other stores'' items';
  assert (select count(*) from public.orders) = 0, '10: seller can read the buyer''s order';
  assert (select shipping_address ->> 'city' from public.seller_orders) = 'Cebu',
    '10: seller lacks the shipping address';
end $$;
reset role;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000b2"}', true);
set local role authenticated;
do $$ begin
  assert (select count(*) from public.seller_orders) = 0, '10: seller 2 sees seller 1''s orders';
  begin
    perform public.set_store_status((select id from public.stores where is_official), 'suspended', 'x');
    raise exception 'FAIL 11: seller suspended a store';
  exception when others then if sqlerrm like 'FAIL%' then raise; end if; end;
end $$;

-- ------------------- fulfillment: each store ships its own part --
reset role;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000b1"}', true);
set local role authenticated;
do $$
declare v_part uuid := (select id from public.seller_orders);
begin
  begin
    perform public.update_seller_order(v_part, 'shipped');
    raise exception 'FAIL: shipped without tracking';
  exception when others then if sqlerrm like 'FAIL%' then raise; end if; end;
  perform public.update_seller_order(v_part, 'confirmed');
  perform public.update_seller_order(v_part, 'shipped', 'J&T Express', 'JT123');
  assert (select status from public.seller_orders where id = v_part) = 'shipped', 'seller part not shipped';
  perform set_config('test.seller1_part', v_part::text, true);
end $$;
reset role;
do $$ begin
  assert (select status from public.orders where id = current_setting('test.split_order')::uuid) = 'toShip',
    'order moved on before every store shipped';
end $$;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000b2"}', true);
set local role authenticated;
do $$ begin
  begin
    perform public.update_seller_order(current_setting('test.seller1_part')::uuid, 'delivered');
    raise exception 'FAIL 10: seller 2 updated seller 1''s order';
  exception when others then if sqlerrm like 'FAIL%' then raise; end if; end;
end $$;
reset role;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000a1"}', true);
set local role authenticated;
do $$ begin
  perform public.update_seller_order(
    (select so.id from public.seller_orders so join public.stores s on s.id = so.store_id
     where so.order_id = current_setting('test.split_order')::uuid and s.is_official),
    'shipped', 'LBC', 'LBC999');
  assert (select status from public.orders where id = current_setting('test.split_order')::uuid) = 'toReceive',
    'order not in transit after every store shipped';
end $$;

-- --------------------------- unpaid online orders give their stock back --
reset role;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000c1"}', true);
set local role authenticated;
do $$
declare r jsonb;
begin
  r := public.place_order('[{"book_id":"00000000-0000-0000-0000-0000000b0002","quantity":3}]',
    '00000000-0000-0000-0000-00000000ad01', 'standard', 'gcash');
  perform set_config('test.gcash_order', r ->> 'id', true);
  assert (select status from public.orders where id = (r ->> 'id')::uuid) = 'pending', 'online order not pending';
end $$;
reset role;
update public.orders set created_at = now() - interval '1 hour'
where id = current_setting('test.gcash_order')::uuid;
do $$
declare v_before int;
begin
  select stock into v_before from public.books where id = '00000000-0000-0000-0000-0000000b0002';
  perform public.expire_stale_orders();
  assert (select status from public.orders where id = current_setting('test.gcash_order')::uuid) = 'failed',
    'stale order not expired';
  assert (select stock from public.books where id = '00000000-0000-0000-0000-0000000b0002') = v_before + 3,
    'stale order stock not returned';
end $$;

-- ------------------------------------------ reviews and messages --
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000c1"}', true);
set local role authenticated;
do $$ begin
  begin
    insert into public.reviews (book_id, order_id, user_id, rating)
    values ('00000000-0000-0000-0000-0000000b0002', current_setting('test.split_order')::uuid, auth.uid(), 5);
    raise exception 'FAIL: reviewed an order that is not completed';
  exception when others then if sqlerrm like 'FAIL%' then raise; end if; end;
  begin
    insert into public.messages (user_id, sender, text) values (auth.uid(), 'store', 'fake reply');
    raise exception 'FAIL: customer posted as the store';
  exception when others then if sqlerrm like 'FAIL%' then raise; end if; end;
  perform public.send_store_welcome();
  perform public.send_store_welcome();
  assert (select count(*) from public.messages where user_id = auth.uid() and sender = 'store') = 1,
    'welcome message missing or duplicated';
end $$;
reset role;
update public.orders set status = 'completed' where id = current_setting('test.split_order')::uuid;
do $$ begin
  assert (select bool_and(status = 'delivered') from public.seller_orders
          where order_id = current_setting('test.split_order')::uuid), 'admin completion did not reach sellers';
end $$;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000c1"}', true);
set local role authenticated;
do $$ begin
  insert into public.reviews (book_id, order_id, user_id, user_name, rating)
  values ('00000000-0000-0000-0000-0000000b0002', current_setting('test.split_order')::uuid, auth.uid(),
          'Totally The Author', 5);
  assert (select user_name from public.reviews where user_id = auth.uid()) = 'Cust 1', 'review name spoofed';
  assert (select rating_count from public.books where id = '00000000-0000-0000-0000-0000000b0002') = 1,
    'review did not update the rating';
  begin
    insert into public.reviews (book_id, order_id, user_id, rating)
    values ('00000000-0000-0000-0000-0000000b0002', current_setting('test.split_order')::uuid, auth.uid(), 1);
    raise exception 'FAIL: reviewed the same order item twice';
  exception when others then if sqlerrm like 'FAIL%' then raise; end if; end;
end $$;

-- ------------------------------------- 15. reading tracker still works --
do $$ begin
  perform public.update_reading_progress('00000000-0000-0000-0000-0000000b0002', 40, 3);
  assert (select streak_count from public.profiles where id = auth.uid()) = 1, '15: streak not updated';
  assert (select progress_percent from public.library_entries
          where user_id = auth.uid() and book_id = '00000000-0000-0000-0000-0000000b0002') = 40,
    '15: progress not saved';
end $$;

reset role;
do $$ begin raise notice 'ALL MARKETPLACE TESTS PASSED'; end $$;
select 'ALL MARKETPLACE TESTS PASSED' as result;

rollback;
