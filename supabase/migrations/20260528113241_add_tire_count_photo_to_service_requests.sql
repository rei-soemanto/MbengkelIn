alter table public.service_requests add column if not exists tire_count integer not null default 1;
alter table public.service_requests add column if not exists photo_url text;

insert into storage.buckets (id, name, public)
values ('order-photos', 'order-photos', true)
on conflict (id) do nothing;

create policy "Authenticated upload order photos"
on storage.objects for insert to authenticated
with check (bucket_id = 'order-photos');

create policy "Public read order photos"
on storage.objects for select
using (bucket_id = 'order-photos');
