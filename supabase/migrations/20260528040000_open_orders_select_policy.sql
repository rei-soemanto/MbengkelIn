-- Realtime postgres_changes enforces RLS: a mechanic only receives change
-- events for rows they can SELECT. Previously the only SELECT policy was
-- (auth.uid() = customer_id), so mechanics got NO realtime events for incoming
-- orders (the order data only reached them via the SECURITY DEFINER edge
-- function on a 5s poll). Allow any authenticated user to read open, unassigned
-- requests so Realtime delivers new orders instantly. This exposes nothing new:
-- the same rows are already returned by nearby_service_requests.

drop policy if exists "Authenticated can view open service requests." on public.service_requests;
create policy "Authenticated can view open service requests."
    on public.service_requests
    for select
    to authenticated
    using (status = 'To Do' and bengkel_id is null);
