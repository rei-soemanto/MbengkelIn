//
//  VehicleViewModel.swift
//  MbengkelIn
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
    
    private let authService = AuthService()
    private let vehicleRepository = VehicleRepository()
    
    func fetchVehicles() async {
        guard let session = try? await authService.getCurrentSession() else { return }
        let uid = session.user.id.uuidString.lowercased()
        
        do {
            let fetchedVehicles = try await vehicleRepository.fetchVehicles(customerId: uid)
            self.userVehicles = fetchedVehicles
        } catch {
            print("Gagal memuat kendaraan: \(error)")
        }
    }
    
    func addVehicle(manufacturer: String, model: String, year: Int, licensePlate: String, color: String) async -> Bool {
        isLoading = true
        errorMessage = nil
        
        guard let session = try? await authService.getCurrentSession() else {
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
            try await vehicleRepository.insertVehicle(newVehicle)
            
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
        
        let payload = VehicleUpdatePayload(
            manufacturer: manufacturer,
            model: model,
            year: year,
            license_plate: licensePlate,
            color: color
        )
            
        do {
            try await vehicleRepository.updateVehicle(vehicleId: vehicleId, payload: payload)
                
            await fetchVehicles()
            self.successMessage = "Kendaraan berhasil diperbarui!"
            isLoading = false
            return true
        } catch {
            self.errorMessage = error.localizedDescription
            isLoading = false
            return false
        }
    }
    
    @discardableResult
    func deleteVehicle(vehicleId: String) async -> Bool {
        errorMessage = nil
        do {
            try await vehicleRepository.deleteVehicle(vehicleId: vehicleId)
            await fetchVehicles()
            return true
        } catch {
            self.errorMessage = error.localizedDescription
            return false
        }
    }
}
