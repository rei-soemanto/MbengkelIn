-- =============================================================================
-- Lock down the SECURITY DEFINER function surface exposed over PostgREST.
-- CRITICAL: increment_user_balance / settle_topup were callable by any
-- authenticated user → free money / self-credited top-ups. Trigger & admin
-- helpers have no business being REST-callable either.
-- (Trigger functions still fire normally — trigger execution does not require the
-- invoking user to hold EXECUTE; and SECURITY DEFINER call chains run as the
-- function owner, so internal calls like settle_topup→increment_user_balance keep working.)
-- =============================================================================

-- Internal money helper: only ever called from other SECURITY DEFINER functions.
revoke execute on function public.increment_user_balance(uuid, double precision) from public, anon, authenticated;

-- Top-up settlement: only the Midtrans webhook (service_role) may settle.
revoke execute on function public.settle_topup(text, text, text) from public, anon, authenticated;
grant  execute on function public.settle_topup(text, text, text) to service_role;

-- Admin-only operations (run via service_role, never the app client).
revoke execute on function public.reject_withdrawal(uuid) from public, anon, authenticated;
grant  execute on function public.reject_withdrawal(uuid) to service_role;
revoke execute on function public.approve_bengkel_and_upgrade_user() from public, anon, authenticated;
grant  execute on function public.approve_bengkel_and_upgrade_user() to service_role;

-- Pure trigger / internal functions: never call directly via the API.
revoke execute on function public.refund_rejected_withdrawal() from public, anon, authenticated;
revoke execute on function public.handle_order_balance() from public, anon, authenticated;
revoke execute on function public.handle_new_user() from public, anon, authenticated;
revoke execute on function public.reject_self_bid() from public, anon, authenticated;
revoke execute on function public.recompute_bengkel_rating() from public, anon, authenticated;
revoke execute on function public.downgrade_user_on_bengkel_delete() from public, anon, authenticated;
revoke execute on function public.normalize_new_service_request() from public, anon, authenticated;
revoke execute on function public.rls_auto_enable() from public, anon, authenticated;

-- User-facing RPCs: keep authenticated, drop the implicit anon/public access.
revoke execute on function public.accept_bid(uuid) from public, anon;
revoke execute on function public.cancel_order(uuid) from public, anon;
revoke execute on function public.rate_order(uuid, integer, text) from public, anon;
revoke execute on function public.mark_order_completed(uuid, text) from public, anon;
revoke execute on function public.open_dispute(uuid, text, text) from public, anon;
revoke execute on function public.request_withdrawal(double precision) from public, anon;
revoke execute on function public.nearby_bengkels(double precision, double precision, double precision) from public, anon;
revoke execute on function public.nearby_service_requests(double precision, double precision, double precision) from public, anon;
grant execute on function public.accept_bid(uuid) to authenticated;
grant execute on function public.cancel_order(uuid) to authenticated;
grant execute on function public.rate_order(uuid, integer, text) to authenticated;
grant execute on function public.mark_order_completed(uuid, text) to authenticated;
grant execute on function public.open_dispute(uuid, text, text) to authenticated;
grant execute on function public.request_withdrawal(double precision) to authenticated;
grant execute on function public.nearby_bengkels(double precision, double precision, double precision) to authenticated;
grant execute on function public.nearby_service_requests(double precision, double precision, double precision) to authenticated;

-- search_path hardening (advisor: function_search_path_mutable).
alter function public.normalize_new_service_request() set search_path = 'public';
alter function public.approve_bengkel_and_upgrade_user() set search_path = 'public';
alter function public.downgrade_user_on_bengkel_delete() set search_path = 'public';
alter function public.handle_new_user() set search_path = 'public';
