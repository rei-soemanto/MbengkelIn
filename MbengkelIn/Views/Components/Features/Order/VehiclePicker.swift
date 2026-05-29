//
//  VehiclePicker.swift
//  MbengkelIn
//
//  Created by Amadeus Eugine Dirgantara on 29/05/26.
//

import SwiftUI

struct VehiclePicker: View {
    let vehicles: [Vehicle]
    let selectedVehicleId: String?
    let onSelect: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Kendaraan yang bermasalah?")
                .font(.headline)
                .padding(.horizontal)

            if vehicles.isEmpty {
                Text("Belum ada kendaraan. Tambahkan di menu Profil.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(vehicles) { vehicle in
                            VehicleChip(
                                vehicle: vehicle,
                                isSelected: selectedVehicleId == vehicle.id,
                                action: {
                                    if let id = vehicle.id { onSelect(id) }
                                }
                            )
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }
}

private struct VehicleChip: View {
    let vehicle: Vehicle
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(vehicle.manufacturer) \(vehicle.model)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(vehicle.licensePlate)
                    .font(.caption)
                    .opacity(0.8)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .foregroundColor(isSelected ? Color(.systemBackground) : .primary)
            .background(isSelected ? Color.primary.opacity(0.9) : Color(.systemGray5))
            .cornerRadius(16)
        }
    }
}

#Preview {
    VehiclePicker(
        vehicles: [
            Vehicle(id: "1", customerId: "c", manufacturer: "Honda", model: "Beat", year: 2020, licensePlate: "L 1234 AB", color: "Black"),
            Vehicle(id: "2", customerId: "c", manufacturer: "Yamaha", model: "NMAX", year: 2022, licensePlate: "W 5678 CD", color: "Blue")
        ],
        selectedVehicleId: "1",
        onSelect: { _ in }
    )
}
