alter table public.users add column if not exists held_balance double precision not null default 0;
alter table public.users add column if not exists pending_balance double precision not null default 0;

create or replace function public.handle_order_balance()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
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

  -- accepted: To Do -> On Progress (money moves into bengkel pending)
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

  -- cancelled: release hold (and bengkel pending if it was in progress)
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
$$;

drop trigger if exists trg_handle_order_balance on public.service_requests;
create trigger trg_handle_order_balance
after insert or update or delete on public.service_requests
for each row execute function public.handle_order_balance();
