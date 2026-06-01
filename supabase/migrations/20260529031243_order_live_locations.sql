create table if not exists public.order_locations (
  service_request_id uuid primary key references public.service_requests(id) on delete cascade,
  provider_uid uuid not null references public.users(id) on delete cascade,
  latitude double precision not null,
  longitude double precision not null,
  updated_at timestamptz not null default now()
);

alter table public.order_locations enable row level security;

-- The assigned provider may publish its own live location for an order.
create policy "Providers insert their order location"
  on public.order_locations
  for insert
  with check (auth.uid() = provider_uid);

create policy "Providers update their order location"
  on public.order_locations
  for update
  using (auth.uid() = provider_uid)
  with check (auth.uid() = provider_uid);

-- Both the order's customer and its provider may read the live location.
create policy "Order parties read live location"
  on public.order_locations
  for select
  using (
    auth.uid() = provider_uid
    or exists (
      select 1 from public.service_requests sr
      where sr.id = order_locations.service_request_id
        and sr.customer_id = auth.uid()
    )
  );

alter publication supabase_realtime add table public.order_locations;
