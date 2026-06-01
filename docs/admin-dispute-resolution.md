# Admin dispute resolution (manual SQL)

When a customer ("Batalkan Pesanan") or a bengkel ("Laporkan Kendala") cancels an
**On Progress** order, the app calls the `open_dispute` RPC. That:

- records a row in `public.order_disputes` (`reason`, optional `proof_url`,
  `initiator_role`, `status = 'pending'`), and
- flips the order to `Cancelled`, which makes `handle_order_balance` **freeze** the
  money: the customer's `held_balance` and the bengkel's `pending_balance` stay in
  place (nobody is paid or refunded yet).

A (conceptual) admin reviews each pending dispute and resolves it by hand. There is
no admin UI or resolve RPC — run one of the snippets below.

## List pending disputes

```sql
select d.id, d.service_request_id, d.initiator_role, d.reason, d.proof_url,
       d.created_at, sr.price, sr.customer_id, sr.bengkel_id
from public.order_disputes d
join public.service_requests sr on sr.id = d.service_request_id
where d.status = 'pending'
order by d.created_at;
```

## Resolve — REFUND the customer (release the hold, bengkel gets nothing)

```sql
do $$
declare
  v_dispute uuid := '<DISPUTE_ID>';
  sr public.service_requests;
  prov uuid;
begin
  select s.* into sr
  from public.order_disputes d join public.service_requests s on s.id = d.service_request_id
  where d.id = v_dispute and d.status = 'pending';
  if not found then raise exception 'No pending dispute %', v_dispute; end if;

  update public.users
    set held_balance = greatest(0, held_balance - coalesce(sr.price,0))
    where id = sr.customer_id;

  select provider_uid into prov from public.bengkels where id = sr.bengkel_id;
  if prov is not null then
    update public.users
      set pending_balance = greatest(0, pending_balance - coalesce(sr.price,0))
      where id = prov;
  end if;

  update public.order_disputes set status = 'refunded', resolved_at = now() where id = v_dispute;
end $$;
```

## Resolve — PAY the bengkel (charge the customer)

```sql
do $$
declare
  v_dispute uuid := '<DISPUTE_ID>';
  sr public.service_requests;
  prov uuid;
begin
  select s.* into sr
  from public.order_disputes d join public.service_requests s on s.id = d.service_request_id
  where d.id = v_dispute and d.status = 'pending';
  if not found then raise exception 'No pending dispute %', v_dispute; end if;

  update public.users
    set balance = balance - coalesce(sr.price,0),
        held_balance = greatest(0, held_balance - coalesce(sr.price,0))
    where id = sr.customer_id;

  select provider_uid into prov from public.bengkels where id = sr.bengkel_id;
  if prov is not null then
    update public.users
      set balance = balance + coalesce(sr.price,0),
          pending_balance = greatest(0, pending_balance - coalesce(sr.price,0))
      where id = prov;
  end if;

  update public.order_disputes set status = 'paid', resolved_at = now() where id = v_dispute;
end $$;
```

> Note: this freeze-on-cancel behaviour supersedes the earlier
> `cancel_accepted_order_charges_customer` migration (which paid the bengkel
> immediately). On-progress cancellations now always go through this dispute flow.
