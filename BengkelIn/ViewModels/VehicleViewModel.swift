//
//  VehicleViewModel.swift
//  BengkelIn
//
//  Created by Rei Soemanto on 24/04/26.
//

import SwiftUI
import Combine
import FirebaseAuth
import FirebaseFirestore

@MainActor
class VehicleViewModel: ObservableObject {
    @Published var userVehicles: [Vehicle] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    
    func fetchVehicles() async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        do {
            let snapshot = try await Firestore.firestore().collection("vehicles")
                .whereField("customerId", isEqualTo: uid)
                .getDocuments()
            
            self.userVehicles = snapshot.documents.compactMap { try? $0.data(as: Vehicle.self) }
        } catch {
            print("Failed to fetch vehicles: \(error)")
        }
    }
    
    func addVehicle(manufacturer: String, model: String, year: Int, licensePlate: String, color: String) async -> Bool {
        isLoading = true
        errorMessage = nil
        guard let uid = Auth.auth().currentUser?.uid else { return false }
        
        let newVehicle = Vehicle(customerId: uid, manufacturer: manufacturer, model: model, year: year, licensePlate: licensePlate, color: color)
        
        do {
            let _ = try Firestore.firestore().collection("vehicles").addDocument(from: newVehicle)
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
            
            do {
                try await Firestore.firestore().collection("vehicles").document(vehicleId).updateData([
                    "manufacturer": manufacturer,
                    "model": model,
                    "year": year,
                    "licensePlate": licensePlate,
                    "color": color
                ])
                
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
            try await Firestore.firestore().collection("vehicles").document(vehicleId).delete()
            await fetchVehicles() 
        } catch {
            print("Failed to delete vehicle: \(error)")
        }
    }
}
