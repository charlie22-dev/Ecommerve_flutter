-- Run on a disposable Supabase database after both payment migrations.
-- Fixtures and simulated verified callbacks are rolled back; no real charge.
begin;
do $$
declare
  v_user uuid := gen_random_uuid();
  v_book uuid := gen_random_uuid();
  v_address uuid := gen_random_uuid();
  v_channel text;
  v_order jsonb;
  v_invoice jsonb;
  v_saved jsonb;
  v_invoice_id text;
  v_before int;
begin
  insert into auth.users(id, email) values (v_user, v_user::text || '@verified-payment.invalid');
  insert into public.addresses(id, user_id, recipient_name, address_line, city)
  values (v_address, v_user, 'Payment fixture', '1 Test Street', 'Cebu');
  insert into public.books(id, title, type, price, stock)
  values (v_book, 'Verified payment fixture', 'manga', 250, 50);
  insert into public.cart_items(user_id, book_id, quantity) values (v_user, v_book, 20);
  perform set_config('request.jwt.claims', jsonb_build_object('sub', v_user)::text, true);

  foreach v_channel in array array['GCASH', 'GRABPAY', 'PAYMAYA', 'CREDIT_CARD', 'BPI'] loop
    v_order := public.place_order(jsonb_build_array(jsonb_build_object(
      'book_id', v_book, 'quantity', 1, 'checkout_source', 'cart')), v_address, 'standard', 'gcash');
    v_invoice_id := 'invoice-' || gen_random_uuid()::text;
    v_invoice := jsonb_build_object('id', v_invoice_id, 'external_id', v_order ->> 'id',
      'status', 'PAID', 'currency', 'PHP', 'amount', 340, 'paid_amount', 340,
      'payment_channel', v_channel, 'payment_method', 'EWALLET',
      'payment_id', 'transaction-' || v_invoice_id, 'paid_at', now());

    -- Invalid amounts must not change status or insert a payment record.
    begin
      perform public.apply_xendit_invoice(v_invoice || '{"amount":1}', 'webhook');
      raise exception 'FAIL: accepted wrong invoice amount';
    exception when others then if sqlerrm like 'FAIL:%' then raise; end if; end;
    begin
      perform public.apply_xendit_invoice(v_invoice || '{"paid_amount":1}', 'webhook');
      raise exception 'FAIL: accepted an underpayment';
    exception when others then if sqlerrm like 'FAIL:%' then raise; end if; end;
    assert (select payment_status from public.orders where id = (v_order ->> 'id')::uuid) = 'pending';
    assert not exists(select 1 from public.order_payments where invoice_id = v_invoice_id);

    select quantity into v_before from public.cart_items where user_id = v_user and book_id = v_book;
    -- Covers both webhook and server-side GET reconciliation through one RPC.
    v_saved := public.apply_xendit_invoice(v_invoice, 'status_check');
    assert v_saved ->> 'payment_status' = 'paid', 'Payment should be paid';
    assert v_saved ->> 'status' = 'toShip', 'Order should move out of pending';
    assert v_saved ->> 'payment_channel' = v_channel, 'Actual channel was lost';
    assert (v_saved ->> 'amount_paid')::numeric = 340, 'Wrong paid amount';
    assert (select quantity from public.cart_items where user_id = v_user and book_id = v_book) = v_before - 1;
    assert (select count(*) from public.order_payments where invoice_id = v_invoice_id) = 1;

    -- Duplicate callback and later settlement update metadata, not fulfillment.
    update public.orders set status = 'toReceive' where id = (v_order ->> 'id')::uuid;
    v_saved := public.apply_xendit_invoice(v_invoice || '{"status":"SETTLED"}', 'webhook');
    v_saved := public.apply_xendit_invoice(v_invoice, 'webhook');
    v_saved := public.apply_xendit_invoice(v_invoice || '{"status":"EXPIRED"}', 'webhook');
    assert v_saved ->> 'status' = 'toReceive', 'Duplicate callback regressed shipment';
    assert v_saved ->> 'payment_status' = 'paid', 'Expiry overwrote a payment';
    assert v_saved ->> 'xendit_invoice_status' = 'SETTLED', 'Out of order callback regressed settlement';
    assert (select quantity from public.cart_items where user_id = v_user and book_id = v_book) = v_before - 1;
  end loop;

  -- A payment arriving after stock has been released still has a durable record.
  v_order := public.place_order(jsonb_build_array(jsonb_build_object('book_id', v_book, 'quantity', 1)),
    v_address, 'standard', 'gcash');
  update public.orders set status = 'failed' where id = (v_order ->> 'id')::uuid;
  v_saved := public.apply_xendit_invoice(v_invoice || jsonb_build_object(
    'id', 'late-' || gen_random_uuid()::text, 'external_id', v_order ->> 'id'), 'webhook');
  assert v_saved ->> 'payment_status' = 'requires_review';
  assert v_saved ->> 'status' = 'failed', 'A late payment must not ship released stock';
  assert exists(select 1 from public.order_payments where order_id = (v_order ->> 'id')::uuid);
  assert not has_function_privilege('authenticated', 'public.apply_xendit_invoice(jsonb,text)', 'EXECUTE'),
    'A shopper must never be able to confirm their own payment';
end $$;
rollback;
select 'VERIFIED ONLINE PAYMENT TESTS PASSED' as result;
