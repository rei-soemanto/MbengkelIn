create policy "Customers delete own service requests."
on public.service_requests for delete
using (auth.uid() = customer_id);
