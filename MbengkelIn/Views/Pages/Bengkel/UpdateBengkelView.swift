//
//  UpdateBengkelView.swift
//  MbengkelIn
//
//  Created by Rei Soemanto on 25/04/26.
//

import SwiftUI
import MapKit

struct UpdateBengkelView: View {
    @ObservedObject var bengkelViewModel: BengkelViewModel
    @ObservedObject var authViewModel: AuthViewModel
    var bengkel: Bengkel

    @Environment(\.dismiss) var dismiss

    @State private var name: String = ""

    var body: some View {
        ZStack(alignment: .topLeading) {
            VStack(spacing: 0) {
                ZStack {
                    OrderMapView(
                        region: $bengkelViewModel.region,
                        isEditing: bengkelViewModel.isEditingLocation,
                        onRegionChange: { coordinate in
                            bengkelViewModel.updateLocationFromMap(coordinate: coordinate)
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
                        address: $bengkelViewModel.locationAddress,
                        isFocused: $bengkelViewModel.isEditingLocation,
                        isFetchingLocation: bengkelViewModel.isFetchingLocation,
                        onCurrentLocationTapped: bengkelViewModel.useCurrentLocation
                    )

                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "building.2")
                                .foregroundColor(.primary)
                                .font(.title2)

                            TextField("Nama Bengkel", text: $name)
                                .font(.body)
                                .foregroundColor(.primary)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .padding(.horizontal)

                        if let errorMessage = bengkelViewModel.errorMessage {
                            Text(errorMessage)
                                .foregroundColor(.red)
                                .font(.footnote)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }

                        Button {
                            Task {
                                guard let id = bengkel.id else { return }
                                let success = await bengkelViewModel.updateBengkel(bengkelId: id, name: name, address: bengkelViewModel.locationAddress)

                                if success {
                                    if let uid = authViewModel.currentUser?.id {
                                        await bengkelViewModel.fetchMyBengkel(uid: uid)
                                    }
                                    dismiss()
                                }
                            }
                        } label: {
                            HStack {
                                if bengkelViewModel.isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: Color(.systemBackground)))
                                }
                                Text("Simpan Perubahan")
                                    .font(.headline)
                            }
                            .foregroundColor(Color(.systemBackground))
                            .frame(maxWidth: .infinity)
                            .frame(height: 55)
                            .background(Color.primary.opacity(0.8))
                            .cornerRadius(12)
                            .shadow(color: Color.primary.opacity(0.15), radius: 10, x: 0, y: 5)
                        }
                        .disabled(bengkelViewModel.isLoading || name.isEmpty || bengkelViewModel.locationAddress.isEmpty)
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
            if bengkelViewModel.isEditingLocation {
                LocationSearchView(viewModel: bengkelViewModel)
                    .transition(.move(edge: .bottom))
                    .zIndex(2)
            }
        }
        .navigationBarHidden(true)
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: bengkelViewModel.isEditingLocation)
        .onAppear {
            self.name = bengkel.name
            bengkelViewModel.locationAddress = bengkel.address
            bengkelViewModel.region = MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: bengkel.latitude, longitude: bengkel.longitude),
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
        }
    }
}
