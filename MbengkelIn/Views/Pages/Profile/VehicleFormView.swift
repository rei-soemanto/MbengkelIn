//
//  VehicleFormView.swift
//  MbengkelIn
//
//  Created by Rei Soemanto on 24/04/26.
//

import SwiftUI

struct VehicleFormView: View {
    @ObservedObject var vehicleViewModel: VehicleViewModel
    
    var vehicleToEdit: Vehicle? = nil 
    
    @Environment(\.dismiss) var dismiss
    
    @State private var manufacturer = ""
    @State private var model = ""
    @State private var yearStr = ""
    @State private var licensePlate = ""
    @State private var color = ""
    
    private var isEditing: Bool {
        vehicleToEdit != nil
    }
    
    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 16) {
                    CustomInputField(iconName: "car", placeholder: "Manufacturer (e.g., Toyota, Honda)", text: $manufacturer)
                    CustomInputField(iconName: "car.side", placeholder: "Model (e.g., Avanza, Beat)", text: $model)
                    CustomInputField(iconName: "calendar", placeholder: "Year (e.g., 2018)", text: $yearStr)
                        .keyboardType(.numberPad)
                    CustomInputField(iconName: "lanyardcard", placeholder: "License Plate (e.g., L 1234 AB)", text: $licensePlate)
                        .autocapitalization(.allCharacters)
                    CustomInputField(iconName: "paintpalette", placeholder: "Color", text: $color)
                    
                    if let errorMessage = vehicleViewModel.errorMessage {
                        Text(errorMessage).foregroundColor(.red).font(.footnote)
                    }
                    
                    Button {
                        Task {
                            let year = Int(yearStr) ?? 2000
                            let success: Bool
                            
                            if isEditing, let id = vehicleToEdit?.id {
                                success = await vehicleViewModel.updateVehicle(
                                    vehicleId: id, manufacturer: manufacturer, model: model, year: year, licensePlate: licensePlate, color: color)
                            } else {
                                success = await vehicleViewModel.addVehicle(
                                    manufacturer: manufacturer, model: model, year: year, licensePlate: licensePlate, color: color)
                            }
                            
                            if success { dismiss() }
                        }
                    } label: {
                        Text(isEditing ? "Update Vehicle" : "Save Vehicle")
                            .font(.headline)
                            .foregroundColor(Color(.systemBackground))
                            .frame(maxWidth: .infinity)
                            .frame(height: 55)
                            .background(Color.primary.opacity(0.8))
                            .cornerRadius(12)
                            .shadow(color: Color.primary.opacity(0.15), radius: 10, x: 0, y: 5)
                    }
                    .padding(.top, 10)
                    .disabled(manufacturer.isEmpty || model.isEmpty || licensePlate.isEmpty || vehicleViewModel.isLoading)
                }
                .padding()
            }
            
            if vehicleViewModel.isLoading {
                ProgressView()
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(10)
                    .shadow(radius: 10)
            }
        }
        .navigationTitle(isEditing ? "Edit Vehicle" : "Add Vehicle")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if let vehicle = vehicleToEdit {
                self.manufacturer = vehicle.manufacturer
                self.model = vehicle.model
                self.yearStr = String(vehicle.year)
                self.licensePlate = vehicle.licensePlate
                self.color = vehicle.color
            }
        }
    }
}
