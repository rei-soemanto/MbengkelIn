alter publication supabase_realtime add table public.topups;
alter publication supabase_realtime add table public.withdrawals;
alter publication supabase_realtime add table public.bengkels;

alter table public.topups replica identity full;
alter table public.withdrawals replica identity full;
alter table public.bengkels replica identity full;
