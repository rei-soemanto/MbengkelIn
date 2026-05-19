//
//  RegisterBengkelView.swift
//  BengkelIn
//
//  Created by Rei Soemanto on 25/04/26.
//

import SwiftUI

struct RegisterBengkelView: View {
    @StateObject private var viewModel = BengkelViewModel()
    @Environment(\.dismiss) var dismiss
    
    @State private var bengkelName = ""
    @State private var bengkelAddress = ""
    @State private var showSuccessAlert = false
    
    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    
                    VStack(spacing: 8) {
                        Image(systemName: "wrench.and.screwdriver.fill")
                            .font(.system(size: 60))
                            .foregroundColor(Color.primary.opacity(0.8))
                            .padding(.bottom, 8)
                        
                        Text("Partner With Us")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text("Register your workshop to start providing roadside assistance.")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding(.top, 30)
                    
                    VStack(spacing: 16) {
                        CustomInputField(
                            iconName: "building.2",
                            placeholder: "Bengkel Name",
                            text: $bengkelName
                        )
                        
                        CustomInputField(
                            iconName: "map",
                            placeholder: "Full Address (e.g., Jl. Raya Darmo No. 123, Surabaya)",
                            text: $bengkelAddress
                        )
                    }
                    
                    if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.footnote)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    
                    Button {
                        Task {
                            let success = await viewModel.registerBengkel(name: bengkelName, address: bengkelAddress)
                            if success {
                                showSuccessAlert = true
                            }
                        }
                    } label: {
                        Text("Submit for Approval")
                            .font(.headline)
                            .foregroundColor(Color(.systemBackground))
                            .frame(maxWidth: .infinity)
                            .frame(height: 55)
                            .background(Color.primary.opacity(bengkelName.isEmpty || bengkelAddress.isEmpty ? 0.4 : 0.9))
                            .cornerRadius(12)
                    }
                    .disabled(bengkelName.isEmpty || bengkelAddress.isEmpty || viewModel.isLoading)
                    .padding(.top, 10)
                    
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "info.circle")
                            .foregroundColor(.blue)
                        Text("Your application will be manually reviewed by our team. Once your role is updated to Provider, you will gain access to the Bengkel Dashboard.")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)
                }
                .padding()
            }
            
            if viewModel.isLoading {
                Color.black.opacity(0.3).ignoresSafeArea()
                ProgressView("Finding location...")
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(10)
                    .shadow(radius: 10)
            }
        }
        .navigationTitle("Register Bengkel")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Registration Submitted!", isPresented: $showSuccessAlert) {
            Button("OK") { dismiss() }
        } message: {
            Text(viewModel.successMessage ?? "Your application is pending review.")
        }
    }
}

#Preview ("Light Mode") {
    RegisterBengkelView()
        .preferredColorScheme(.light)
}

#Preview ("Dark Mode") {
    RegisterBengkelView()
        .preferredColorScheme(.dark)
}
