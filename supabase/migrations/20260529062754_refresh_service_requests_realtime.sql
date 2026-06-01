-- Realtime's cached relation for service_requests still referenced the old
-- "photo_url" column (renamed to "photo_urls"), breaking apply_rls so no
-- service_requests change was delivered. Re-add the table to rebuild the
-- relation, and use full replica identity so RLS works for UPDATE/DELETE too.
alter publication supabase_realtime drop table service_requests;
alter table public.service_requests replica identity full;
alter publication supabase_realtime add table service_requests;
