-- order_locations is consumed via a *filtered* realtime subscription
-- (service_request_id=eq.<id>) on the customer side. Filtered UPDATE events
-- require replica identity full so the row columns are present for the filter
-- to match — otherwise the customer receives the bengkel's first position but
-- no live movement. Matches the convention already applied to service_requests.
alter table public.order_locations replica identity full;
