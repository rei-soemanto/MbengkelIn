-- =============================================================================
-- RLS / privilege hardening. The permissive policies + blanket column GRANTs let
-- any authenticated user directly write columns that the SECURITY DEFINER RPCs are
-- supposed to own, bypassing every server-side guard. Lock them to the RPCs.
-- (SECURITY DEFINER functions run as the function owner and keep full column
-- privileges, so all money/state RPCs and triggers continue to work.)
-- =============================================================================

-- 1) users: a client could set its OWN balance / held_balance / pending_balance /
--    role directly (infinite money + privilege escalation). The users row is
--    created by the signup trigger, never the client.
revoke insert on public.users from authenticated, anon;
revoke update on public.users from authenticated, anon;
-- Re-grant ONLY the genuinely client-editable profile columns.
grant update (name, profile_image_url, bank_name, bank_account_number, bank_account_name)
  on public.users to authenticated;

-- 2) service_requests: the open "Customers update own service requests" UPDATE
--    policy + full column grant let a customer set status / bengkel_id / price /
--    rating / *_completed directly — bypassing accept_bid, rate_order and
--    mark_order_completed. Take away direct UPDATE entirely; all transitions go
--    through SECURITY DEFINER RPCs (accept_bid, mark_order_completed, rate_order,
--    open_dispute, cancel_order).
revoke update on public.service_requests from authenticated, anon;
drop policy if exists "Customers update own service requests." on public.service_requests;
-- Redundant duplicate of "Providers view assigned service requests."
drop policy if exists "Providers view their assigned requests." on public.service_requests;

-- The bidding-phase cancel (customer gives up while still 'To Do') previously did a
-- direct status UPDATE; replace it with an owner-checked RPC so direct UPDATE can
-- stay revoked. On-Progress cancellation continues to go through open_dispute.
create or replace function public.cancel_order(p_request_id uuid)
returns public.service_requests
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  sr public.service_requests;
begin
  select * into sr from public.service_requests where id = p_request_id for update;
  if not found then
    raise exception 'Order not found';
  end if;
  if sr.customer_id <> auth.uid() then
    raise exception 'Not authorized for this order';
  end if;
  -- Only a still-searching order may be cancelled this way; an accepted order
  -- must be disputed (open_dispute), not silently cancelled.
  if sr.status <> 'To Do' then
    raise exception 'Order cannot be cancelled';
  end if;

  update public.service_requests
    set status = 'Cancelled', updated_at = now()
    where id = p_request_id;

  select * into sr from public.service_requests where id = p_request_id;
  return sr;
end;
$function$;
grant execute on function public.cancel_order(uuid) to authenticated;

-- Defensive: normalize every client-inserted order so a customer can't insert a
-- pre-assigned / pre-completed / pre-rated row. Orders always start fresh in 'To Do'.
create or replace function public.normalize_new_service_request()
returns trigger
language plpgsql
as $function$
begin
  new.status := 'To Do';
  new.bengkel_id := null;
  new.customer_completed := false;
  new.provider_completed := false;
  new.rating := null;
  new.review := null;
  new.completed_at := null;
  new.assigned_at := null;
  return new;
end;
$function$;
drop trigger if exists trg_normalize_new_service_request on public.service_requests;
create trigger trg_normalize_new_service_request
  before insert on public.service_requests
  for each row execute function public.normalize_new_service_request();

-- 3) bids: the "Customers update bids on their requests" policy let a customer set a
--    bid's status to 'Accepted' directly, bypassing accept_bid's balance check and
--    atomic order assignment. Acceptance is owned by the accept_bid RPC; customers
--    never write bids directly.
drop policy if exists "Customers update bids on their requests." on public.bids;
