-- 1) open_dispute: customer OR assigned provider cancels an in-progress order
--    for review. Records the reason (+ optional proof) and flips the order to
--    Cancelled; the balance trigger then FREEZES the money (no payout/refund).
create or replace function public.open_dispute(
  p_request_id uuid,
  p_reason text,
  p_proof_url text default null
)
returns public.service_requests
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  sr public.service_requests;
  is_customer boolean;
  is_provider boolean;
  v_role text;
begin
  select * into sr from public.service_requests where id = p_request_id;
  if not found then
    raise exception 'Order not found';
  end if;

  is_customer := (sr.customer_id = auth.uid());
  is_provider := exists (
    select 1 from public.bengkels b
    where b.id = sr.bengkel_id and b.provider_uid = auth.uid()
  );
  if not (is_customer or is_provider) then
    raise exception 'Not authorized for this order';
  end if;
  if sr.status <> 'On Progress' then
    raise exception 'Order is not in progress';
  end if;
  if coalesce(btrim(p_reason), '') = '' then
    raise exception 'A reason is required';
  end if;

  v_role := case when is_customer then 'customer' else 'provider' end;

  insert into public.order_disputes
    (service_request_id, initiated_by, initiator_role, reason, proof_url)
  values
    (p_request_id, auth.uid(), v_role, btrim(p_reason), p_proof_url);

  update public.service_requests
    set status = 'Cancelled', updated_at = now()
    where id = p_request_id;

  select * into sr from public.service_requests where id = p_request_id;
  return sr;
end;
$function$;

grant execute on function public.open_dispute(uuid, text, text) to authenticated;

-- 2) mark_order_completed now also stores the provider's completion proof photo.
--    Replaces the single-arg version (callers may pass one or two args).
drop function if exists public.mark_order_completed(uuid);

create or replace function public.mark_order_completed(
  p_request_id uuid,
  p_completion_photo_url text default null
)
returns public.service_requests
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  sr public.service_requests;
  is_customer boolean;
  is_provider boolean;
begin
  select * into sr from public.service_requests where id = p_request_id;
  if not found then
    raise exception 'Order not found';
  end if;

  is_customer := (sr.customer_id = auth.uid());
  is_provider := exists (
    select 1 from public.bengkels b
    where b.id = sr.bengkel_id and b.provider_uid = auth.uid()
  );
  if not (is_customer or is_provider) then
    raise exception 'Not authorized for this order';
  end if;
  if sr.status <> 'On Progress' then
    raise exception 'Order is not in progress';
  end if;

  if is_customer then
    update public.service_requests set customer_completed = true where id = p_request_id;
  end if;
  if is_provider then
    update public.service_requests
      set provider_completed = true,
          completion_photo_url = coalesce(p_completion_photo_url, completion_photo_url)
      where id = p_request_id;
  end if;

  update public.service_requests
    set status = 'Done', completed_at = now()
    where id = p_request_id and customer_completed and provider_completed;

  select * into sr from public.service_requests where id = p_request_id;
  return sr;
end;
$function$;

grant execute on function public.mark_order_completed(uuid, text) to authenticated;

-- 3) Freeze money on an in-progress cancellation (dispute escrow). To Do
--    cancellations still just release the hold. Supersedes the
--    charge-on-cancel logic from cancel_accepted_order_charges_customer.
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

  -- cancelled
  if NEW.status = 'Cancelled' and OLD.status <> 'Cancelled' then
    if OLD.status = 'On Progress' then
      -- Disputed cancellation: FREEZE funds (customer hold + bengkel pending stay
      -- in place) until an admin resolves order_disputes manually:
      --   REFUND : held_balance -= price (customer); pending_balance -= price (bengkel)
      --   PAY    : balance -= price & held_balance -= price (customer);
      --            balance += price & pending_balance -= price (bengkel)
      -- then set order_disputes.status = 'refunded' | 'paid', resolved_at = now().
      null;
    else
      -- Not yet accepted (To Do): release the hold, no charge.
      update public.users set held_balance = greatest(0, held_balance - coalesce(OLD.price,0)) where id = NEW.customer_id;
    end if;
  end if;

  return NEW;
end;
$function$;
