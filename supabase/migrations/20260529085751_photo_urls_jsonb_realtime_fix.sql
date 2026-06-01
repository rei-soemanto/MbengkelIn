alter table public.service_requests
  alter column photo_urls drop default;

alter table public.service_requests
  alter column photo_urls type jsonb
  using to_jsonb(coalesce(photo_urls, '{}'::text[]));

alter table public.service_requests
  alter column photo_urls set default '[]'::jsonb;

drop function if exists public.nearby_service_requests(double precision, double precision, double precision);

create function public.nearby_service_requests(
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
$function$;
