-- 1) A provider may only mark an order completed WITH a completion photo. The
-- client makes the photo mandatory in the UI; this is the server backstop.
create or replace function public.mark_order_completed(p_request_id uuid, p_completion_photo_url text default null::text)
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
    -- Mandatory proof-of-work: a provider cannot complete without a photo
    -- (either passed now or already stored).
    if coalesce(p_completion_photo_url, sr.completion_photo_url) is null then
      raise exception 'Foto penyelesaian wajib dilampirkan';
    end if;
    update public.service_requests
      set provider_completed = true,
          completion_photo_url = coalesce(p_completion_photo_url, completion_photo_url)
      where id = p_request_id;
  end if;

  update public.service_requests
    set status = 'Done', completed_at = now()
    where id = p_request_id and customer_completed and provider_completed;

  select * into sr from public.service_requests where id = p_request_id;
  return sr;
end;
$function$;

-- 2) Server-authoritative rating: a customer may rate their OWN order, only once,
-- and only after it is Done. Replaces the client's open table UPDATE.
create or replace function public.rate_order(p_request_id uuid, p_rating int, p_review text default null::text)
returns service_requests
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  sr public.service_requests;
begin
  if p_rating < 1 or p_rating > 5 then
    raise exception 'Rating must be between 1 and 5';
  end if;

  update public.service_requests
    set rating = p_rating,
        review = p_review
    where id = p_request_id
      and customer_id = auth.uid()
      and status = 'Done'
      and rating is null
    returning * into sr;

  if not found then
    raise exception 'Order cannot be rated';
  end if;

  return sr;
end;
$function$;

grant execute on function public.rate_order(uuid, int, text) to authenticated;
