-- Post-order behavior reports: after an order is Done or Cancelled, either party
-- (the customer or the assigned bengkel's provider) can report unfriendly
-- behavior by the other side. Reviewed by a (conceptual) admin.
create table if not exists public.behavior_reports (
  id uuid primary key default gen_random_uuid(),
  service_request_id uuid not null references public.service_requests(id) on delete cascade,
  reporter_id uuid not null references public.users(id) on delete cascade,
  reason text not null,
  created_at timestamptz not null default now()
);

create index if not exists behavior_reports_request_idx on public.behavior_reports(service_request_id);

alter table public.behavior_reports enable row level security;

-- A party to the order can file a report under their own id.
create policy "Order parties insert reports"
  on public.behavior_reports
  for insert
  with check (
    auth.uid() = reporter_id
    and (
      exists (
        select 1 from public.service_requests sr
        where sr.id = service_request_id and sr.customer_id = auth.uid()
      )
      or exists (
        select 1 from public.service_requests sr
        join public.bengkels b on b.id = sr.bengkel_id
        where sr.id = service_request_id and b.provider_uid = auth.uid()
      )
    )
  );

-- Reporters can read back their own reports.
create policy "Reporters view own reports"
  on public.behavior_reports
  for select
  using (auth.uid() = reporter_id);
