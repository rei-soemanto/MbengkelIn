alter table public.service_requests
  add column if not exists rating int check (rating between 1 and 5),
  add column if not exists review text;

create or replace function public.recompute_bengkel_rating()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  target_bengkel uuid;
begin
  target_bengkel := coalesce(new.bengkel_id, old.bengkel_id);
  if target_bengkel is null then
    return coalesce(new, old);
  end if;

  update public.bengkels b
  set average_rating = coalesce(agg.avg_rating, 0),
      total_reviews = coalesce(agg.cnt, 0)
  from (
    select avg(rating)::float8 as avg_rating, count(rating) as cnt
    from public.service_requests
    where bengkel_id = target_bengkel and rating is not null
  ) agg
  where b.id = target_bengkel;

  return coalesce(new, old);
end;
$$;

drop trigger if exists trg_recompute_bengkel_rating on public.service_requests;
create trigger trg_recompute_bengkel_rating
after insert or update of rating or delete on public.service_requests
for each row execute function public.recompute_bengkel_rating();
