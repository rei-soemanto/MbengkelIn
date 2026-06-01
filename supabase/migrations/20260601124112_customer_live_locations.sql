-- Customer-side live location for an in-progress order, mirroring
-- order_locations (which carries the bengkel's live location). Kept as a
-- separate table so the two writers never clobber each other and RLS stays simple.
create table if not exists public.customer_locations (
  service_request_id uuid primary key references public.service_requests(id) on delete cascade,
  customer_id uuid not null references public.users(id) on delete cascade,
  latitude double precision not null,
  longitude double precision not null,
  updated_at timestamptz not null default now()
);

alter table public.customer_locations enable row level security;

-- The order's customer publishes their own live location.
create policy "Customers insert their order location"
  on public.customer_locations
  for insert
  with check (auth.uid() = customer_id);

create policy "Customers update their order location"
  on public.customer_locations
  for update
  using (auth.uid() = customer_id)
  with check (auth.uid() = customer_id);

-- Both the order's customer and its assigned provider may read it.
create policy "Order parties read customer location"
  on public.customer_locations
  for select
  using (
    auth.uid() = customer_id
    or exists (
      select 1 from public.service_requests sr
      join public.bengkels b on b.id = sr.bengkel_id
      where sr.id = customer_locations.service_request_id
        and b.provider_uid = auth.uid()
    )
  );

-- Realtime: published + full replica identity so the bengkel's *filtered*
-- (service_request_id=eq.<id>) UPDATE subscription receives live movement.
alter publication supabase_realtime add table public.customer_locations;
alter table public.customer_locations replica identity full;
