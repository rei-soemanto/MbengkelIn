-- Withdrawals must be backed by AVAILABLE balance (balance - held_balance), so
-- money escrowed for active orders can't be withdrawn.
create or replace function public.request_withdrawal(p_amount double precision)
returns uuid
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
    v_uid uuid := auth.uid();
    v_balance double precision;
    v_held double precision;
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

    select balance, held_balance, bank_name, bank_account_number, bank_account_name
      into v_balance, v_held, v_bank_name, v_bank_account_number, v_bank_account_name
    from public.users
    where id = v_uid
    for update;

    if v_bank_account_number is null or v_bank_account_number = '' then
        raise exception 'Bank account is not set';
    end if;
    if (v_balance - coalesce(v_held, 0)) < p_amount then
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
$function$;
