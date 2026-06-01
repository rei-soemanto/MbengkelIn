-- Customers may delete only non-active orders. Active 'On Progress' orders must
-- be cancelled via open_dispute, never hard-deleted.
drop policy if exists "Customers delete own service requests." on public.service_requests;
create policy "Customers delete own service requests."
  on public.service_requests
  for delete
  using (auth.uid() = customer_id and status in ('To Do','Cancelled','Done'));
