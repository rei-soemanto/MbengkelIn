drop policy if exists "Authenticated can view open service requests." on public.service_requests;
create policy "Authenticated can view open service requests."
    on public.service_requests
    for select
    to authenticated
    using (status = 'To Do' and bengkel_id is null);
