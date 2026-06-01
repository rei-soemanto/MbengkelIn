-- Remove the 'Ganti Lampu' service category entirely.
-- Postgres cannot drop a value from an enum, so the ServiceType enum is
-- recreated without it. Verified that no service_requests rows (and no
-- bengkels.offered_services JSONB) reference 'Ganti Lampu', so the column
-- cast below cannot fail. service_requests.service_type is the only column
-- using this enum, and no functions depend on it.

alter type "ServiceType" rename to "ServiceType__old";

create type "ServiceType" as enum (
  'Ban Gembos',
  'Ban Pecah',
  'Aki Kering',
  'Kehabisan Bensin',
  'Mogok / Mesin Mati',
  'Ganti Ban Serep',
  'Rantai Motor Lepas',
  'Mesin Overheat'
);

alter table public.service_requests
  alter column service_type type "ServiceType"
  using service_type::text::"ServiceType";

drop type "ServiceType__old";
