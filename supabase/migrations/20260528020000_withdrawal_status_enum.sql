-- Promote withdrawals.status from free text to a constrained enum, matching the
-- ServiceStatus / BengkelStatus convention. Values kept lowercase so the existing
-- request_withdrawal / reject_withdrawal RPCs and the Swift UI keep working as-is.

do $$
begin
    if not exists (select 1 from pg_type where typname = 'WithdrawalStatus') then
        create type "WithdrawalStatus" as enum ('pending', 'approved', 'rejected', 'paid');
    end if;
end$$;

alter table public.withdrawals alter column status drop default;

alter table public.withdrawals
    alter column status type "WithdrawalStatus"
    using status::"WithdrawalStatus";

alter table public.withdrawals alter column status set default 'pending';
