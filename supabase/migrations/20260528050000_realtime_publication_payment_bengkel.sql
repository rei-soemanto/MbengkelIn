-- Make topups, withdrawals, and bengkels truly realtime (no client polling).
-- Both are required for Realtime to deliver: publication membership AND RLS that
-- lets the subscriber SELECT the rows (already satisfied: topups/withdrawals
-- select-own, bengkels "Anyone can view"). REPLICA IDENTITY FULL ensures filtered
-- UPDATE/DELETE events carry the row columns so subscription filters match.

alter publication supabase_realtime add table public.topups;
alter publication supabase_realtime add table public.withdrawals;
alter publication supabase_realtime add table public.bengkels;

alter table public.topups replica identity full;
alter table public.withdrawals replica identity full;
alter table public.bengkels replica identity full;
