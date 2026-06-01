-- Proof photo the bengkel must upload when completing an order.
alter table public.service_requests add column if not exists completion_photo_url text;

-- Cancellations-under-review (escrow). When a customer or bengkel cancels an
-- in-progress order, the money is FROZEN (held/pending stay put) and a dispute
-- row records the reason + proof. A (conceptual) admin later resolves it
-- manually via SQL (see handle_order_balance comments).
create table if not exists public.order_disputes (
  id uuid primary key default gen_random_uuid(),
  service_request_id uuid not null references public.service_requests(id) on delete cascade,
  initiated_by uuid not null references public.users(id),
  initiator_role text not null check (initiator_role in ('customer','provider')),
  reason text not null,
  proof_url text,
  status text not null default 'pending' check (status in ('pending','refunded','paid')),
  created_at timestamptz not null default now(),
  resolved_at timestamptz
);

create index if not exists order_disputes_request_idx on public.order_disputes(service_request_id);

alter table public.order_disputes enable row level security;

-- The order's customer and its assigned provider can read its dispute(s).
-- Inserts happen only through the SECURITY DEFINER open_dispute() RPC, so there
-- is intentionally no INSERT policy here.
create policy "Order parties view disputes"
  on public.order_disputes
  for select
  using (
    auth.uid() = initiated_by
    or exists (
      select 1 from public.service_requests sr
      where sr.id = order_disputes.service_request_id and sr.customer_id = auth.uid()
    )
    or exists (
      select 1 from public.service_requests sr
      join public.bengkels b on b.id = sr.bengkel_id
      where sr.id = order_disputes.service_request_id and b.provider_uid = auth.uid()
    )
  );
