//
//  VehicleViewModel.swift
//  BengkelIn
//
//  Created by Rei Soemanto on 24/04/26.
//

import SwiftUI
import Combine
import Supabase

@MainActor
class VehicleViewModel: ObservableObject {
    @Published var userVehicles: [Vehicle] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    
    func fetchVehicles() async {
        guard let session = try? await supabase.auth.session else { return }
        let uid = session.user.id.uuidString.lowercased()
        
        do {
            let fetchedVehicles: [Vehicle] = try await supabase.from("vehicles")
                .select()
                .eq("customer_id", value: uid)
                .execute()
                .value
            
            self.userVehicles = fetchedVehicles
        } catch {
            print("Failed to fetch vehicles: \(error)")
        }
    }
    
    func addVehicle(manufacturer: String, model: String, year: Int, licensePlate: String, color: String) async -> Bool {
        isLoading = true
        errorMessage = nil
        
        guard let session = try? await supabase.auth.session else {
            isLoading = false
            return false
        }
        let uid = session.user.id.uuidString.lowercased()
        
        let newVehicle = Vehicle(
            id: nil,
            customerId: uid,
            manufacturer: manufacturer,
            model: model,
            year: year,
            licensePlate: licensePlate,
            color: color,
            createdAt: nil
        )
        
        do {
            try await supabase.from("vehicles").insert(newVehicle).execute()
            
            await fetchVehicles()
            isLoading = false
            return true
        } catch {
            self.errorMessage = error.localizedDescription
            isLoading = false
            return false
        }
    }
    
    func updateVehicle(vehicleId: String, manufacturer: String, model: String, year: Int, licensePlate: String, color: String) async -> Bool {
        isLoading = true
        errorMessage = nil
        
        struct VehicleUpdate: Encodable {
            let manufacturer: String
            let model: String
            let year: Int
            let license_plate: String
            let color: String
        }
        
        let updateData = VehicleUpdate(
            manufacturer: manufacturer,
            model: model,
            year: year,
            license_plate: licensePlate,
            color: color
        )
            
        do {
            try await supabase.from("vehicles")
                .update(updateData)
                .eq("id", value: vehicleId)
                .execute()
                
            await fetchVehicles()
            self.successMessage = "Vehicle updated successfully!"
            isLoading = false
            return true
        } catch {
            self.errorMessage = error.localizedDescription
            isLoading = false
            return false
        }
    }
    
    func deleteVehicle(vehicleId: String) async {
        do {
            try await supabase.from("vehicles")
                .delete()
                .eq("id", value: vehicleId)
                .execute()
                
            await fetchVehicles()
        } catch {
            print("Failed to delete vehicle: \(error)")
        }
    }
}
