create table if not exists public.bids (
  id uuid primary key default gen_random_uuid(),
  service_request_id uuid not null references public.service_requests(id) on delete cascade,
  provider_uid uuid not null references public.users(id) on delete cascade,
  bengkel_id uuid not null references public.bengkels(id) on delete cascade,
  price bigint not null,
  notes text,
  status text not null default 'Pending',
  created_at timestamptz not null default now(),
  unique (service_request_id, provider_uid)
);

alter table public.bids enable row level security;

create index if not exists bids_service_request_id_idx on public.bids(service_request_id);
create index if not exists bids_provider_uid_idx on public.bids(provider_uid);

create policy "Customers insert own service requests."
  on public.service_requests for insert
  with check (auth.uid() = customer_id);

create policy "Customers view own service requests."
  on public.service_requests for select
  using (auth.uid() = customer_id);

create policy "Customers update own service requests."
  on public.service_requests for update
  using (auth.uid() = customer_id)
  with check (auth.uid() = customer_id);

create policy "Mechanics insert own bids."
  on public.bids for insert
  with check (auth.uid() = provider_uid);

create policy "Mechanics view own bids."
  on public.bids for select
  using (auth.uid() = provider_uid);

create policy "Customers view bids on their requests."
  on public.bids for select
  using (exists (
    select 1 from public.service_requests sr
    where sr.id = bids.service_request_id and sr.customer_id = auth.uid()
  ));

create policy "Customers update bids on their requests."
  on public.bids for update
  using (exists (
    select 1 from public.service_requests sr
    where sr.id = bids.service_request_id and sr.customer_id = auth.uid()
  ))
  with check (exists (
    select 1 from public.service_requests sr
    where sr.id = bids.service_request_id and sr.customer_id = auth.uid()
  ));

create or replace function public.nearby_service_requests(
  p_lat double precision,
  p_lon double precision,
  p_radius_m double precision default 5000
)
returns table (
  id uuid,
  customer_id uuid,
  customer_name text,
  service_type text,
  description text,
  is_emergency boolean,
  latitude double precision,
  longitude double precision,
  price bigint,
  status text,
  created_at timestamptz,
  distance_m double precision
)
language sql
security definer
set search_path = public
as $$
  select
    sr.id,
    sr.customer_id,
    u.name as customer_name,
    sr.service_type::text,
    sr.description,
    sr.is_emergency,
    sr.latitude,
    sr.longitude,
    sr.price,
    sr.status::text,
    sr.created_at,
    6371000 * 2 * asin(sqrt(
      power(sin(radians(sr.latitude - p_lat) / 2), 2) +
      cos(radians(p_lat)) * cos(radians(sr.latitude)) *
      power(sin(radians(sr.longitude - p_lon) / 2), 2)
    )) as distance_m
  from public.service_requests sr
  join public.users u on u.id = sr.customer_id
  where sr.bengkel_id is null
    and sr.status = 'To Do'
    and sr.latitude is not null
    and sr.longitude is not null
    and 6371000 * 2 * asin(sqrt(
      power(sin(radians(sr.latitude - p_lat) / 2), 2) +
      cos(radians(p_lat)) * cos(radians(sr.latitude)) *
      power(sin(radians(sr.longitude - p_lon) / 2), 2)
    )) <= p_radius_m
  order by distance_m asc;
$$;

create or replace function public.nearby_bengkels(
  p_lat double precision,
  p_lon double precision,
  p_radius_m double precision default 5000
)
returns table (
  id uuid,
  provider_uid uuid,
  name text,
  address text,
  latitude double precision,
  longitude double precision,
  average_rating double precision,
  total_reviews integer,
  offered_services jsonb,
  distance_m double precision
)
language sql
security definer
set search_path = public
as $$
  select
    b.id,
    b.provider_uid,
    b.name,
    b.address,
    b.latitude,
    b.longitude,
    b.average_rating,
    b.total_reviews,
    b.offered_services,
    6371000 * 2 * asin(sqrt(
      power(sin(radians(b.latitude - p_lat) / 2), 2) +
      cos(radians(p_lat)) * cos(radians(b.latitude)) *
      power(sin(radians(b.longitude - p_lon) / 2), 2)
    )) as distance_m
  from public.bengkels b
  where b.status = 'Verified'
    and 6371000 * 2 * asin(sqrt(
      power(sin(radians(b.latitude - p_lat) / 2), 2) +
      cos(radians(p_lat)) * cos(radians(b.latitude)) *
      power(sin(radians(b.longitude - p_lon) / 2), 2)
    )) <= p_radius_m
  order by distance_m asc;
$$;

revoke all on function public.nearby_service_requests(double precision, double precision, double precision) from public;
revoke all on function public.nearby_bengkels(double precision, double precision, double precision) from public;
grant execute on function public.nearby_service_requests(double precision, double precision, double precision) to authenticated;
grant execute on function public.nearby_bengkels(double precision, double precision, double precision) to authenticated;
