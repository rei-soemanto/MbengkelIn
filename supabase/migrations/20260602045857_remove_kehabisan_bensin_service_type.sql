-- Remove the 'Kehabisan Bensin' service category. The fuel-out flow was dropped
-- in favour of the generic vehicle+location order flow, so the Swift ServiceType
-- enum has no matching case and no client path ever produces this value.
-- Postgres cannot drop a value from an enum, so ServiceType is recreated without
-- it. Verified: 0 service_requests rows use it, and service_requests.service_type
-- is the only column/dependency on the type (no functions reference it).

alter type "ServiceType" rename to "ServiceType__old";

create type "ServiceType" as enum (
  'Ban Gembos',
  'Ban Pecah',
  'Aki Kering',
  'Mogok / Mesin Mati',
  'Ganti Ban Serep',
  'Rantai Motor Lepas',
  'Mesin Overheat'
);

alter table public.service_requests
  alter column service_type type "ServiceType"
  using service_type::text::"ServiceType";

drop type "ServiceType__old";
