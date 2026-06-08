-- Allow deleting a vehicle that still has service_requests referencing it.
-- Previously service_requests_vehicle_id_fkey was ON DELETE NO ACTION, so deleting
-- a vehicle with any order history threw a foreign-key violation. Orders are meant to
-- outlive the vehicle (the human-readable label is preserved denormalized in
-- service_requests.vehicle_info), so on delete we null out the reference instead of
-- blocking. The frontend renders vehicle_id IS NULL (with vehicle_info present) as
-- "Kendaraan dihapus".

ALTER TABLE public.service_requests
  DROP CONSTRAINT service_requests_vehicle_id_fkey,
  ADD  CONSTRAINT service_requests_vehicle_id_fkey
    FOREIGN KEY (vehicle_id) REFERENCES public.vehicles(id) ON DELETE SET NULL;
