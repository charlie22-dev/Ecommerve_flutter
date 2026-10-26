begin;
-- Verified online payment metadata and atomic reconciliation.
alter table public.orders add column if not exists payment_status text not null default 'pending'
  check (payment_status in ('pending', 'paid', 'unpaid', 'expired', 'requires_review'));
alter table public.orders add column if not exists payment_channel text;
alter table public.orders add column if not exists provider_payment_method text;
alter table public.orders add column if not exists xendit_payment_id text;
alter table public.orders add column if not exists xendit_invoice_status text;
alter table public.orders add column if not exists amount_paid numeric(10, 2);
alter table public.orders add column if not exists payment_currency text;
alter table public.orders add column if not exists payment_verified_at timestamptz;

update public.orders set payment_status = 'unpaid'
where payment_method = 'cashOnDelivery' and payment_status = 'pending';

create or replace function public.initialize_order_payment_status()
returns trigger language plpgsql set search_path = public as $$
begin
  new.payment_status := case when new.payment_method = 'cashOnDelivery' then 'unpaid' else 'pending' end;
  return new;
end $$;
drop trigger if exists orders_initialize_payment_status on public.orders;
create trigger orders_initialize_payment_status before insert on public.orders
  for each row execute function public.initialize_order_payment_status();

create table if not exists public.order_payments (
  invoice_id text primary key,
  order_id uuid not null references public.orders(id) on delete cascade,
  provider text not null default 'xendit',
  provider_status text not null,
  payment_id text,
  payment_method text,
  payment_channel text,
  amount numeric(10, 2) not null,
  amount_paid numeric(10, 2),
  currency text not null,
  paid_at timestamptz,
  verification_source text not null check (verification_source in ('webhook', 'status_check')),
  details jsonb not null default '{}',
  verified_at timestamptz not null default now()
);
create index if not exists order_payments_order_idx on public.order_payments(order_id);
alter table public.order_payments enable row level security;
revoke all on public.order_payments from anon, authenticated;
grant select on public.order_payments to authenticated;
drop policy if exists "order_payments: buyer or admin read" on public.order_payments;
create policy "order_payments: buyer or admin read" on public.order_payments
for select to authenticated using (
  public.is_admin() or exists (
    select 1 from public.orders o where o.id = order_id and o.user_id = auth.uid()
  )
);

-- Only Edge Functions holding the service role may call this function.
-- Invoice data must come from an authenticated Xendit callback or its GET API.
create or replace function public.apply_xendit_invoice(p_invoice jsonb, p_source text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_order orders;
  v_invoice_id text := nullif(p_invoice ->> 'id', '');
  v_status text := p_invoice ->> 'status';
  v_paid boolean := coalesce(v_status in ('PAID', 'SETTLED'), false);
  v_amount numeric := (p_invoice ->> 'amount')::numeric;
  v_paid_amount numeric;
  v_paid_at timestamptz;
  v_channel text := coalesce(nullif(p_invoice ->> 'payment_channel', ''),
    nullif(p_invoice ->> 'ewallet_type', ''), nullif(p_invoice ->> 'bank_code', ''));
  v_snapshot jsonb;
  v_first_paid boolean;
begin
  if p_source not in ('webhook', 'status_check') or p_source is null then
    raise exception 'Invalid verification source';
  end if;
  if v_invoice_id is null or v_status is null or v_status not in ('PENDING', 'PAID', 'SETTLED', 'EXPIRED') then
    raise exception 'Invalid invoice';
  end if;
  select * into v_order from orders where id = (p_invoice ->> 'external_id')::uuid for update;
  if not found then raise exception 'Order not found'; end if;
  if v_order.payment_method = 'cashOnDelivery' then raise exception 'This order is cash on delivery'; end if;
  if v_order.xendit_invoice_id is not null and v_order.xendit_invoice_id <> v_invoice_id then
    raise exception 'Invoice does not match this order';
  end if;
  if p_invoice ->> 'currency' is distinct from 'PHP' or v_amount is null or v_amount <= 0
     or round(v_amount, 2) <> v_order.total then
    raise exception 'Invoice currency or amount does not match this order';
  end if;
  if v_paid then
    v_paid_amount := coalesce((p_invoice ->> 'paid_amount')::numeric, v_amount);
    if v_paid_amount < v_order.total then raise exception 'Payment amount is insufficient'; end if;
    v_paid_at := coalesce((p_invoice ->> 'paid_at')::timestamptz, v_order.paid_at, now());
  end if;
  -- Old pending/expired callbacks must never undo a recorded payment.
  if v_order.payment_status in ('paid', 'requires_review') and not v_paid then
    return to_jsonb(v_order);
  end if;
  if v_order.xendit_invoice_status = 'SETTLED' and v_status = 'PAID' then
    v_status := 'SETTLED';
  end if;
  v_first_paid := v_paid and v_order.payment_status not in ('paid', 'requires_review');
  v_snapshot := jsonb_strip_nulls(jsonb_build_object(
    'id', v_invoice_id, 'external_id', v_order.id, 'status', v_status,
    'amount', v_amount, 'paid_amount', v_paid_amount, 'currency', 'PHP',
    'payment_id', p_invoice ->> 'payment_id', 'payment_method', p_invoice ->> 'payment_method',
    'payment_channel', v_channel, 'paid_at', v_paid_at
  ));
  insert into order_payments (invoice_id, order_id, provider_status, payment_id,
    payment_method, payment_channel, amount, amount_paid, currency, paid_at,
    verification_source, details)
  values (v_invoice_id, v_order.id, v_status, p_invoice ->> 'payment_id',
    p_invoice ->> 'payment_method', v_channel, v_amount, v_paid_amount, 'PHP',
    v_paid_at, p_source, v_snapshot)
  on conflict (invoice_id) do update set
    provider_status = excluded.provider_status,
    payment_id = coalesce(excluded.payment_id, order_payments.payment_id),
    payment_method = coalesce(excluded.payment_method, order_payments.payment_method),
    payment_channel = coalesce(excluded.payment_channel, order_payments.payment_channel),
    amount_paid = coalesce(excluded.amount_paid, order_payments.amount_paid),
    paid_at = coalesce(excluded.paid_at, order_payments.paid_at),
    verification_source = excluded.verification_source,
    details = order_payments.details || excluded.details, verified_at = now();

  update orders set
    xendit_invoice_id = v_invoice_id,
    xendit_invoice_status = v_status,
    xendit_payment_id = coalesce(p_invoice ->> 'payment_id', xendit_payment_id),
    payment_channel = coalesce(v_channel, payment_channel),
    provider_payment_method = coalesce(p_invoice ->> 'payment_method', provider_payment_method),
    payment_currency = 'PHP',
    amount_paid = coalesce(v_paid_amount, amount_paid),
    payment_verified_at = now(),
    paid_at = case when v_paid then v_paid_at else paid_at end,
    payment_status = case
      when v_paid and status in ('cancelled', 'failed') then 'requires_review'
      when v_paid then 'paid'
      when v_status = 'EXPIRED' then 'expired'
      else payment_status end,
    status = case
      when v_paid and status = 'pending' then 'toShip'
      when v_status = 'EXPIRED' and status = 'pending' then 'failed'
      else status end
  where id = v_order.id returning * into v_order;
  -- Order status triggers confirm seller shipments and clean purchased cart
  -- quantities in this transaction. Repeat callbacks don't repeat those effects.
  if v_first_paid then
    insert into notifications (user_id, category, title, body, related_order_id)
    values (v_order.user_id, 'orderUpdate',
      case when v_order.payment_status = 'paid' then 'Payment received' else 'Payment received - review needed' end,
      case when v_order.payment_status = 'paid' then 'Your online payment is confirmed. Your order is being prepared.'
           else 'We received payment for a closed order. Please contact support for assistance.' end,
      v_order.id);
  end if;
  return to_jsonb(v_order);
end $$;
revoke execute on function public.apply_xendit_invoice(jsonb, text) from public, anon, authenticated;
grant execute on function public.apply_xendit_invoice(jsonb, text) to service_role;
commit;
select 'VERIFIED ONLINE PAYMENT SETUP READY' as result;
