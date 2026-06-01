-- A cancellation should leave everyone's money exactly as before the order:
-- release the customer's hold and reverse the bengkel's pending (no charge, no
-- payout). This replaces the escrow "freeze" (which locked the customer's
-- available balance and caused false "saldo tidak cukup" on the next order).
-- The order_disputes row still records the reason/proof for the admin.
create or replace function public.handle_order_balance()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  prov uuid;
begin
  if (TG_OP = 'INSERT') then
    if NEW.status = 'To Do' and NEW.price is not null then
      update public.users set held_balance = held_balance + NEW.price where id = NEW.customer_id;
    end if;
    return NEW;
  end if;

  if (TG_OP = 'DELETE') then
    if OLD.price is not null and OLD.status in ('To Do','On Progress') then
      update public.users set held_balance = greatest(0, held_balance - OLD.price) where id = OLD.customer_id;
      if OLD.status = 'On Progress' then
        select provider_uid into prov from public.bengkels where id = OLD.bengkel_id;
        if prov is not null then
          update public.users set pending_balance = greatest(0, pending_balance - OLD.price) where id = prov;
        end if;
      end if;
    end if;
    return OLD;
  end if;

  -- price changed while still searching
  if OLD.status = 'To Do' and NEW.status = 'To Do'
     and coalesce(NEW.price,0) <> coalesce(OLD.price,0) then
    update public.users
      set held_balance = greatest(0, held_balance + coalesce(NEW.price,0) - coalesce(OLD.price,0))
      where id = NEW.customer_id;
  end if;

  -- accepted: To Do -> On Progress (move into bengkel pending)
  if OLD.status = 'To Do' and NEW.status = 'On Progress' then
    if coalesce(NEW.price,0) <> coalesce(OLD.price,0) then
      update public.users
        set held_balance = greatest(0, held_balance + coalesce(NEW.price,0) - coalesce(OLD.price,0))
        where id = NEW.customer_id;
    end if;
    select provider_uid into prov from public.bengkels where id = NEW.bengkel_id;
    if prov is not null then
      update public.users set pending_balance = pending_balance + coalesce(NEW.price,0) where id = prov;
    end if;
  end if;

  -- completed: On Progress -> Done (settle both sides)
  if OLD.status = 'On Progress' and NEW.status = 'Done' then
    update public.users
      set balance = balance - coalesce(NEW.price,0),
          held_balance = greatest(0, held_balance - coalesce(NEW.price,0))
      where id = NEW.customer_id;
    select provider_uid into prov from public.bengkels where id = NEW.bengkel_id;
    if prov is not null then
      update public.users
        set balance = balance + coalesce(NEW.price,0),
            pending_balance = greatest(0, pending_balance - coalesce(NEW.price,0))
        where id = prov;
    end if;
  end if;

  -- cancelled (To Do OR On Progress): unwind reservations, charge nobody.
  if NEW.status = 'Cancelled' and OLD.status <> 'Cancelled' then
    update public.users set held_balance = greatest(0, held_balance - coalesce(OLD.price,0)) where id = NEW.customer_id;
    if OLD.status = 'On Progress' then
      select provider_uid into prov from public.bengkels where id = OLD.bengkel_id;
      if prov is not null then
        update public.users set pending_balance = greatest(0, pending_balance - coalesce(OLD.price,0)) where id = prov;
      end if;
    end if;
  end if;

  return NEW;
end;
$function$;

-- One-time correction: rebuild held/pending from currently-active orders, which
-- releases money that past cancellations left frozen.
update public.users u set held_balance = coalesce((
  select sum(sr.price) from public.service_requests sr
  where sr.customer_id = u.id and sr.status in ('To Do','On Progress')
), 0);

update public.users u set pending_balance = coalesce((
  select sum(sr.price) from public.service_requests sr
  join public.bengkels b on b.id = sr.bengkel_id
  where b.provider_uid = u.id and sr.status = 'On Progress'
), 0);
