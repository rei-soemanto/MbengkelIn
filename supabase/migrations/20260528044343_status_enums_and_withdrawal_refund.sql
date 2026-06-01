do $$
begin
    if not exists (select 1 from pg_type where typname = 'TopupStatus') then
        create type "TopupStatus" as enum ('pending', 'success', 'failed', 'expired', 'cancelled');
    end if;
end$$;

alter table public.topups alter column status drop default;
alter table public.topups
    alter column status type "TopupStatus" using status::"TopupStatus";
alter table public.topups alter column status set default 'pending';

do $$
begin
    if not exists (select 1 from pg_type where typname = 'BidStatus') then
        create type "BidStatus" as enum ('Pending', 'Accepted', 'Rejected', 'AutoRejected');
    end if;
end$$;

alter table public.bids alter column status drop default;
alter table public.bids
    alter column status type "BidStatus" using status::"BidStatus";
alter table public.bids alter column status set default 'Pending';

create or replace function public.refund_rejected_withdrawal()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
    if NEW.status = 'rejected'
       and OLD.status is distinct from NEW.status
       and OLD.status <> 'paid' then
        update public.users
        set balance = balance + NEW.amount
        where id = NEW.user_id;
    end if;
    return NEW;
end;
$$;

drop trigger if exists trg_refund_rejected_withdrawal on public.withdrawals;
create trigger trg_refund_rejected_withdrawal
    after update of status on public.withdrawals
    for each row
    execute function public.refund_rejected_withdrawal();

create or replace function public.reject_withdrawal(p_withdrawal_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
    v_status "WithdrawalStatus";
begin
    select status into v_status
    from public.withdrawals
    where id = p_withdrawal_id
    for update;

    if v_status is null then
        raise exception 'Withdrawal not found';
    end if;
    if v_status <> 'pending' then
        raise exception 'Only pending withdrawals can be rejected';
    end if;

    update public.withdrawals
       set status = 'rejected', updated_at = now()
     where id = p_withdrawal_id;
end;
$$;
