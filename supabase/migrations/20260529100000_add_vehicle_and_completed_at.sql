alter table public.service_requests add column if not exists vehicle_id uuid references public.vehicles(id);
alter table public.service_requests add column if not exists vehicle_info text;
alter table public.service_requests add column if not exists completed_at timestamp with time zone;

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
    and 6371000 * 2 * asin(sqrt(
      power(sin(radians(sr.latitude - p_lat) / 2), 2) +
      cos(radians(p_lat)) * cos(radians(sr.latitude)) *
      power(sin(radians(sr.longitude - p_lon) / 2), 2)
    )) <= p_radius_m
  order by distance_m asc;
$function$;

create or replace function public.mark_order_completed(p_request_id uuid)
returns service_requests
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  sr public.service_requests;
  is_customer boolean;
  is_provider boolean;
begin
  select * into sr from public.service_requests where id = p_request_id;
  if not found then
    raise exception 'Order not found';
  end if;

  is_customer := (sr.customer_id = auth.uid());
  is_provider := exists (
    select 1 from public.bengkels b
    where b.id = sr.bengkel_id and b.provider_uid = auth.uid()
  );

  if not (is_customer or is_provider) then
    raise exception 'Not authorized for this order';
  end if;

  if sr.status <> 'On Progress' then
    raise exception 'Order is not in progress';
  end if;

  if is_customer then
    update public.service_requests set customer_completed = true where id = p_request_id;
  end if;
  if is_provider then
    update public.service_requests set provider_completed = true where id = p_request_id;
  end if;

  update public.service_requests
    set status = 'Done', completed_at = now()
    where id = p_request_id and customer_completed and provider_completed;

  select * into sr from public.service_requests where id = p_request_id;
  return sr;
end;
$function$;
