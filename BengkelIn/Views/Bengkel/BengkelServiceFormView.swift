//
//  BengkelServiceFormView.swift
//  BengkelIn
//
//  Created by Rei Soemanto on 26/04/26.
//

import SwiftUI

struct BengkelServiceFormView: View {
    @ObservedObject var bengkelViewModel: BengkelViewModel
    
    var serviceToEdit: BengkelService? = nil
    
    @Environment(\.dismiss) var dismiss
    
    @State private var serviceName: String = ""
    @State private var description: String = ""
    @State private var isActive: Bool = true
    
    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 20) {
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text(serviceToEdit == nil ? "Add New Service" : "Edit Service")
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("Describe a service you offer. Customers will propose a price via bidding.")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 10)
                    
                    CustomInputField(iconName: "wrench.adjustable", placeholder: "Service Name (e.g., Oil Change)", text: $serviceName)
                    
                    CustomInputField(iconName: "text.alignleft", placeholder: "Description", text: $description)
                    
                    Toggle("Service is Active", isOn: $isActive)
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                    
                    if let errorMessage = bengkelViewModel.errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.footnote)
                    }
                    
                    Button {
                        Task {
                            guard let id = bengkelViewModel.myBengkel?.id else { return }
                            
                            let success: Bool
                            if let existingService = serviceToEdit {
                                // EDIT MODE
                                success = await bengkelViewModel.updateService(
                                    bengkelId: id,
                                    serviceId: existingService.id,
                                    serviceName: serviceName,
                                    description: description,
                                    isActive: isActive
                                )
                            } else {
                                // ADD MODE
                                success = await bengkelViewModel.addService(
                                    bengkelId: id,
                                    serviceName: serviceName,
                                    description: description,
                                    isActive: isActive
                                )
                            }
                            
                            if success {
                                dismiss()
                            }
                        }
                    } label: {
                        Text(serviceToEdit == nil ? "Save Service" : "Update Service")
                            .font(.headline)
                            .foregroundColor(Color(.systemBackground))
                            .frame(maxWidth: .infinity)
                            .frame(height: 55)
                            .background(Color.primary.opacity(serviceName.isEmpty || description.isEmpty ? 0.4 : 0.9))
                            .cornerRadius(12)
                    }
                    .disabled(serviceName.isEmpty || description.isEmpty || bengkelViewModel.isLoading)
                    .padding(.top, 10)
                }
                .padding()
            }
            
            if bengkelViewModel.isLoading {
                Color.black.opacity(0.3).ignoresSafeArea()
                ProgressView()
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(10)
                    .shadow(radius: 10)
            }
        }
        .navigationTitle(serviceToEdit == nil ? "New Service" : "Edit Service")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if let service = serviceToEdit {
                serviceName = service.serviceName
                description = service.description
                isActive = service.isActive
            }
        }
    }
}
