-- Server-authoritative bid acceptance: one transaction, balance-checked, with a
-- legal-transition guard. Replaces the client's 3-write sequence + racy balance math.
create or replace function public.accept_bid(p_bid_id uuid)
returns public.service_requests
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_bid public.bids;
  sr public.service_requests;
  v_available double precision;
begin
  select * into v_bid from public.bids where id = p_bid_id;
  if not found then
    raise exception 'Bid not found';
  end if;

  -- lock the order row for the duration of the transaction
  select * into sr from public.service_requests where id = v_bid.service_request_id for update;
  if not found then
    raise exception 'Order not found';
  end if;

  if sr.customer_id <> auth.uid() then
    raise exception 'Not authorized for this order';
  end if;
  if sr.status <> 'To Do' or sr.bengkel_id is not null then
    raise exception 'Order no longer open';
  end if;

  select (balance - held_balance) into v_available from public.users where id = sr.customer_id;
  if v_available is null or v_available < v_bid.price then
    raise exception 'Saldo tidak cukup';
  end if;

  update public.bids set status = 'Accepted' where id = v_bid.id;
  update public.bids set status = 'AutoRejected'
    where service_request_id = v_bid.service_request_id and id <> v_bid.id;

  update public.service_requests
    set status = 'On Progress',
        bengkel_id = v_bid.bengkel_id,
        price = v_bid.price,
        assigned_at = now(),
        updated_at = now()
    where id = sr.id;

  select * into sr from public.service_requests where id = sr.id;
  return sr;
end;
$function$;

grant execute on function public.accept_bid(uuid) to authenticated;
