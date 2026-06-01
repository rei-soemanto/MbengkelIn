-- Atomic, idempotent top-up settlement: credit the balance AND flip the topup
-- status in one transaction, and never double-credit an already-successful topup.
create or replace function public.settle_topup(
  p_order_id text,
  p_status text,
  p_payment_type text default null
)
returns void
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_topup public.topups;
begin
  select * into v_topup from public.topups where order_id = p_order_id for update;
  if not found then
    raise exception 'Top-up not found';
  end if;

  -- Idempotent: a topup that already settled to success is never touched again
  -- (no double-credit, no downgrade).
  if v_topup.status = 'success' then
    return;
  end if;

  if p_status = 'success' then
    perform public.increment_user_balance(v_topup.user_id, v_topup.gross_amount);
  end if;

  update public.topups
    set status = p_status::"TopupStatus",
        payment_type = coalesce(p_payment_type, payment_type),
        updated_at = now()
    where order_id = p_order_id;
end;
$function$;

grant execute on function public.settle_topup(text, text, text) to service_role, authenticated;
