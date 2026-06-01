-- Chat messages between a service request's customer and the assigned bengkel's provider
create table if not exists public.chat_messages (
  id uuid primary key default gen_random_uuid(),
  service_request_id uuid not null references public.service_requests(id) on delete cascade,
  sender_id uuid not null references public.users(id),
  content text,
  image_url text,
  created_at timestamptz not null default now(),
  constraint chat_messages_content_or_image check (content is not null or image_url is not null)
);

create index if not exists chat_messages_request_idx
  on public.chat_messages(service_request_id, created_at);

alter table public.chat_messages enable row level security;

-- Participants (customer or assigned provider) can read the thread
create policy "Participants view messages" on public.chat_messages
for select using (
  exists (
    select 1 from public.service_requests sr
    where sr.id = chat_messages.service_request_id
      and (
        sr.customer_id = auth.uid()
        or exists (
          select 1 from public.bengkels b
          where b.id = sr.bengkel_id and b.provider_uid = auth.uid()
        )
      )
  )
);

-- Participants can send only while the order is unfinished (locks chat once Done/Cancelled)
create policy "Participants send messages" on public.chat_messages
for insert with check (
  sender_id = auth.uid()
  and exists (
    select 1 from public.service_requests sr
    where sr.id = chat_messages.service_request_id
      and sr.status in ('To Do','On Progress')
      and (
        sr.customer_id = auth.uid()
        or exists (
          select 1 from public.bengkels b
          where b.id = sr.bengkel_id and b.provider_uid = auth.uid()
        )
      )
  )
);

-- True realtime delivery (no polling)
alter publication supabase_realtime add table public.chat_messages;

-- Dual confirmation before an order is marked Done
alter table public.service_requests
  add column if not exists customer_completed boolean not null default false,
  add column if not exists provider_completed boolean not null default false;

-- Each party confirms via this RPC; status flips to Done only when both confirmed.
create or replace function public.mark_order_completed(p_request_id uuid)
returns public.service_requests
language plpgsql
security definer
set search_path = public
as $$
declare
  sr public.service_requests;
  is_customer boolean;
  is_provider boolean;
begin
  select * into sr from public.service_requests where id = p_request_id;
  if not found then
    raise exception 'Order not found';
  end if;

  is_customer := (sr.customer_id = auth.uid());
  is_provider := exists (
    select 1 from public.bengkels b
    where b.id = sr.bengkel_id and b.provider_uid = auth.uid()
  );

  if not (is_customer or is_provider) then
    raise exception 'Not authorized for this order';
  end if;

  if sr.status <> 'On Progress' then
    raise exception 'Order is not in progress';
  end if;

  if is_customer then
    update public.service_requests set customer_completed = true where id = p_request_id;
  end if;
  if is_provider then
    update public.service_requests set provider_completed = true where id = p_request_id;
  end if;

  update public.service_requests
    set status = 'Done'
    where id = p_request_id and customer_completed and provider_completed;

  select * into sr from public.service_requests where id = p_request_id;
  return sr;
end;
$$;

grant execute on function public.mark_order_completed(uuid) to authenticated;

-- Public bucket for chat image messages
insert into storage.buckets (id, name, public)
values ('chat-images', 'chat-images', true)
on conflict (id) do nothing;

create policy "Auth upload chat images" on storage.objects
for insert to authenticated
with check (bucket_id = 'chat-images');

create policy "Public read chat images" on storage.objects
for select using (bucket_id = 'chat-images');
