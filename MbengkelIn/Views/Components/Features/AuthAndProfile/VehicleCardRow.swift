//
//  VehicleCardRow.swift
//  MbengkelIn
//
//  Created by Rei Soemanto on 23/04/26.
//

import SwiftUI

struct VehicleCardRow: View {
    @ObservedObject var vehicleViewModel: VehicleViewModel
    var vehicle: Vehicle
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(vehicle.manufacturer) \(vehicle.model)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text("\(vehicle.licensePlate) • \(String(vehicle.year))")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            NavigationLink(destination: VehicleFormView(vehicleViewModel: vehicleViewModel, vehicleToEdit: vehicle)) {
                Image(systemName: "ellipsis")
                    .foregroundColor(.gray)
                    .padding(8)
                    .background(Color(.systemGray5))
                    .clipShape(Circle())
            }
            
            Button(action: {
                Task {
                    if let id = vehicle.id {
                        await vehicleViewModel.deleteVehicle(vehicleId: id)
                    }
                }
            }) {
                Image(systemName: "xmark")
                    .foregroundColor(.white)
                    .padding(8)
                    .background(Color.red)
                    .clipShape(Circle())
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}
