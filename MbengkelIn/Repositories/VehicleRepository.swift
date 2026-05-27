//
//  VehicleRepository.swift
//  MbengkelIn
//
//  Created by Rei Soemanto on 27/05/26.
//

import Foundation
import Supabase

class VehicleRepository {
    func fetchVehicles(customerId: String) async throws -> [Vehicle] {
        return try await supabase.from("vehicles")
            .select()
            .eq("customer_id", value: customerId)
            .execute()
            .value
    }
    
    func insertVehicle(_ vehicle: Vehicle) async throws {
        try await supabase.from("vehicles")
            .insert(vehicle)
            .execute()
    }
    
    func updateVehicle(vehicleId: String, payload: VehicleUpdatePayload) async throws {
        try await supabase.from("vehicles")
            .update(payload)
            .eq("id", value: vehicleId)
            .execute()
    }
    
    func deleteVehicle(vehicleId: String) async throws {
        try await supabase.from("vehicles")
            .delete()
            .eq("id", value: vehicleId)
            .execute()
    }
}
