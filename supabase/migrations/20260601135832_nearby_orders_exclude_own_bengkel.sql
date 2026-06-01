-- Exclude the querying provider's OWN orders from their mechanic feed: a
-- customer who is also a bengkel owner shouldn't be matched with their own
-- bengkel (they can't bid on their own request). `auth.uid()` is the calling
-- provider (the RPC is invoked with the user's JWT). `is distinct from` keeps
-- the feed working even if auth.uid() is somehow null (no rows wrongly dropped).
create or replace function public.nearby_service_requests(
  p_lat double precision,
  p_lon double precision,
  p_radius_m double precision default 5000
)
returns table(
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
  tire_count integer,
  photo_urls jsonb,
  vehicle_id uuid,
  vehicle_info text,
  created_at timestamp with time zone,
  distance_m double precision
)
language sql
security definer
set search_path to 'public'
as $function$
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
    sr.tire_count,
    sr.photo_urls,
    sr.vehicle_id,
    sr.vehicle_info,
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
    and sr.customer_id is distinct from auth.uid()
    and 6371000 * 2 * asin(sqrt(
      power(sin(radians(sr.latitude - p_lat) / 2), 2) +
      cos(radians(p_lat)) * cos(radians(sr.latitude)) *
      power(sin(radians(sr.longitude - p_lon) / 2), 2)
    )) <= p_radius_m
  order by distance_m asc;
$function$;
