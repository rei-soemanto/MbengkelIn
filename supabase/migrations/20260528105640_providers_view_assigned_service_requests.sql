create policy "Providers view assigned service requests."
on public.service_requests for select
using (
  exists (
    select 1 from public.bengkels b
    where b.id = service_requests.bengkel_id
      and b.provider_uid = auth.uid()
  )
);
