-- Backstop for the bidding edge function's self-bid guard: even if a bid row is
-- inserted/updated by any path, a bengkel may never bid on their own order
-- (provider_uid == the order's customer_id).
create or replace function public.reject_self_bid()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_customer_id uuid;
begin
  select customer_id into v_customer_id
    from public.service_requests
    where id = new.service_request_id;
  if v_customer_id is not null and v_customer_id = new.provider_uid then
    raise exception 'Tidak dapat menawar order sendiri';
  end if;
  return new;
end;
$function$;

drop trigger if exists trg_reject_self_bid on public.bids;
create trigger trg_reject_self_bid
  before insert or update on public.bids
  for each row execute function public.reject_self_bid();
