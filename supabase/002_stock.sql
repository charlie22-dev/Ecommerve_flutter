-- =============================================================================
-- BookVerse — automatic stock tracking for orders
--
-- Run once in SQL Editor (already included in schema.sql for new projects).
-- Safe to re-run.
--
--  * Placing an order takes its items out of stock — and fails with
--    "Out of stock: <title>" if there aren't enough, so nobody can buy more
--    than you have.
--  * Cancelling (or failing) an order puts the items back.
-- Runs as SECURITY DEFINER because shoppers can't edit `books` themselves.
-- =============================================================================

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
