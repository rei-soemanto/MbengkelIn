ALTER TABLE public.service_requests ADD COLUMN IF NOT EXISTS photo_urls text[];

UPDATE public.service_requests
SET photo_urls = ARRAY[photo_url]
WHERE photo_url IS NOT NULL AND photo_urls IS NULL;

ALTER TABLE public.service_requests DROP COLUMN IF EXISTS photo_url;

DROP FUNCTION IF EXISTS public.nearby_service_requests(double precision, double precision, double precision);

CREATE OR REPLACE FUNCTION public.nearby_service_requests(p_lat double precision, p_lon double precision, p_radius_m double precision DEFAULT 5000)
 RETURNS TABLE(id uuid, customer_id uuid, customer_name text, service_type text, description text, is_emergency boolean, latitude double precision, longitude double precision, price bigint, status text, tire_count integer, photo_urls text[], created_at timestamp with time zone, distance_m double precision)
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
$function$
