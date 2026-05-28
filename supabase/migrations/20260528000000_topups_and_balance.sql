-- Top-up (balance) feature: transactions table + atomic balance credit.

create table if not exists public.topups (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references public.users(id) on delete cascade,
    order_id text not null unique,
    gross_amount double precision not null,
    status text not null default 'pending',
    payment_type text,
    redirect_url text,
    snap_token text,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create index if not exists topups_user_id_idx on public.topups (user_id);

alter table public.topups enable row level security;

-- Users can read only their own top-up history.
-- Inserts/updates are performed exclusively by the edge functions using the
-- service-role key, which bypasses RLS — so no write policies are exposed to clients.
drop policy if exists "topups_select_own" on public.topups;
create policy "topups_select_own"
    on public.topups
    for select
    using (auth.uid() = user_id);

-- Atomic balance credit, called by the webhook edge function on a settled payment.
create or replace function public.increment_user_balance(p_user_id uuid, p_amount double precision)
returns void
language sql
security definer
set search_path = public
as $$
    update public.users
    set balance = balance + p_amount
    where id = p_user_id;
$$;
