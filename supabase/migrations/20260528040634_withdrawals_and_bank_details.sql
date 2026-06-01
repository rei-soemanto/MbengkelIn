alter table public.users
    add column if not exists bank_name text,
    add column if not exists bank_account_number text,
    add column if not exists bank_account_name text;

create table if not exists public.withdrawals (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references public.users(id) on delete cascade,
    amount double precision not null,
    bank_name text,
    bank_account_number text,
    bank_account_name text,
    status text not null default 'pending',
    notes text,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create index if not exists withdrawals_user_id_idx on public.withdrawals (user_id);

alter table public.withdrawals enable row level security;

drop policy if exists "withdrawals_select_own" on public.withdrawals;
create policy "withdrawals_select_own"
    on public.withdrawals
    for select
    using (auth.uid() = user_id);

create or replace function public.request_withdrawal(p_amount double precision)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
    v_uid uuid := auth.uid();
    v_balance double precision;
    v_bank_name text;
    v_bank_account_number text;
    v_bank_account_name text;
    v_id uuid;
begin
    if v_uid is null then
        raise exception 'Not authenticated';
    end if;
    if p_amount < 10000 then
        raise exception 'Minimum withdrawal is Rp10.000';
    end if;

    select balance, bank_name, bank_account_number, bank_account_name
      into v_balance, v_bank_name, v_bank_account_number, v_bank_account_name
    from public.users
    where id = v_uid
    for update;

    if v_bank_account_number is null or v_bank_account_number = '' then
        raise exception 'Bank account is not set';
    end if;
    if v_balance < p_amount then
        raise exception 'Insufficient balance';
    end if;

    update public.users set balance = balance - p_amount where id = v_uid;

    insert into public.withdrawals
        (user_id, amount, bank_name, bank_account_number, bank_account_name, status)
    values
        (v_uid, p_amount, v_bank_name, v_bank_account_number, v_bank_account_name, 'pending')
    returning id into v_id;

    return v_id;
end;
$$;

create or replace function public.reject_withdrawal(p_withdrawal_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
    v_user_id uuid;
    v_amount double precision;
    v_status text;
begin
    select user_id, amount, status
      into v_user_id, v_amount, v_status
    from public.withdrawals
    where id = p_withdrawal_id
    for update;

    if v_user_id is null then
        raise exception 'Withdrawal not found';
    end if;
    if v_status <> 'pending' then
        raise exception 'Only pending withdrawals can be rejected';
    end if;

    update public.users set balance = balance + v_amount where id = v_user_id;
    update public.withdrawals
       set status = 'rejected', updated_at = now()
     where id = p_withdrawal_id;
end;
$$;
