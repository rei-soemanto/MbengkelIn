//
//  RegisterBengkelView.swift
//  MbengkelIn
//
//  Created by Rei Soemanto on 25/04/26.
//

import SwiftUI
import MapKit

struct RegisterBengkelView: View {
    @StateObject private var viewModel = BengkelViewModel()
    @Environment(\.dismiss) var dismiss

    @State private var bengkelName = ""
    @State private var showSuccessAlert = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            VStack(spacing: 0) {
                // Map
                ZStack {
                    OrderMapView(
                        region: $viewModel.region,
                        isEditing: viewModel.isEditingLocation,
                        onRegionChange: { coordinate in
                            viewModel.updateLocationFromMap(coordinate: coordinate)
                        }
                    )

                    VStack(spacing: 0) {
                        Image(systemName: "mappin")
                            .font(.system(size: 40, weight: .bold))
                            .foregroundColor(.primary)

                        Circle()
                            .fill(Color.primary.opacity(0.3))
                            .frame(width: 12, height: 12)
                            .scaleEffect(x: 2, y: 1)
                            .padding(.top, -2)
                    }
                    .offset(y: -19)
                    .allowsHitTesting(false)
                }
                .ignoresSafeArea(edges: .top)

                // Controls
                VStack(spacing: 0) {
                    LocationInputCard(
                        address: $viewModel.locationAddress,
                        isFocused: $viewModel.isEditingLocation,
                        isFetchingLocation: viewModel.isFetchingLocation,
                        onCurrentLocationTapped: viewModel.useCurrentLocation
                    )

                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "building.2")
                                .foregroundColor(.primary)
                                .font(.title2)

                            TextField("Nama Bengkel", text: $bengkelName)
                                .font(.body)
                                .foregroundColor(.primary)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .padding(.horizontal)

                        if let errorMessage = viewModel.errorMessage {
                            Text(errorMessage)
                                .foregroundColor(.red)
                                .font(.footnote)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }

                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "info.circle")
                                .foregroundColor(.blue)
                            Text("Pengajuan Anda akan ditinjau secara manual oleh tim kami. Setelah peran Anda diperbarui menjadi Penyedia, Anda akan mendapatkan akses ke Dasbor Bengkel.")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(12)
                        .padding(.horizontal)

                        Button {
                            Task {
                                let success = await viewModel.registerBengkel(name: bengkelName, address: viewModel.locationAddress)
                                if success {
                                    showSuccessAlert = true
                                }
                            }
                        } label: {
                            HStack {
                                if viewModel.isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: Color(.systemBackground)))
                                }
                                Text("Kirim untuk Persetujuan")
                                    .font(.headline)
                            }
                            .foregroundColor(Color(.systemBackground))
                            .frame(maxWidth: .infinity)
                            .frame(height: 55)
                            .background(Color.primary.opacity(bengkelName.isEmpty || viewModel.locationAddress.isEmpty ? 0.4 : 0.9))
                            .cornerRadius(12)
                        }
                        .disabled(bengkelName.isEmpty || viewModel.locationAddress.isEmpty || viewModel.isLoading)
                        .padding(.horizontal)
                        .padding(.bottom, 20)
                    }
                    .padding(.top, 16)
                }
                .background(Color(.systemBackground))
            }

            // Back button (sibling, within safe area)
            Button(action: {
                dismiss()
            }) {
                Image(systemName: "chevron.left")
                    .font(.title2)
                    .foregroundColor(.primary)
                    .padding()
                    .background(Color(.systemBackground))
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
            }
            .padding(.top, 8)
            .padding(.leading, 20)

            // Search overlay
            if viewModel.isEditingLocation {
                LocationSearchView(viewModel: viewModel)
                    .transition(.move(edge: .bottom))
                    .zIndex(2)
            }
        }
        .navigationBarHidden(true)
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: viewModel.isEditingLocation)
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
