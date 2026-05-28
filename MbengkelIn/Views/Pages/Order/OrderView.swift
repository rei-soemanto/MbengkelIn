//
//  OrderView.swift
//  MbengkelIn
//
//  Created by Bryan Fernando Dinata on 19/05/26.
//

import SwiftUI
import MapKit
import CoreLocation
import PhotosUI

struct OrderView: View {
    @StateObject private var viewModel = OrderViewModel()
    @Environment(\.presentationMode) var presentationMode
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var didRequestInitialLocation = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            VStack(spacing: 0) {
                // ── Map (top, fully visible — never covered by the controls) ──
                ZStack {
                    OrderMapView(
                        region: $viewModel.region,
                        isEditing: viewModel.isEditingLocation,
                        onRegionChange: { coordinate in
                            viewModel.updateLocationFromMap(coordinate: coordinate)
                        }
                    )

                    // Center marker: the ground dot sits exactly on the map center,
                    // which is the coordinate that gets saved.
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

                // ── Controls (bottom panel, no overlap with the map) ──
                VStack(spacing: 0) {
                    LocationInputCard(
                        address: $viewModel.locationAddress,
                        isFocused: $viewModel.isEditingLocation,
                        isFetchingLocation: viewModel.isFetchingLocation,
                        onCurrentLocationTapped: viewModel.useCurrentLocation
                    )

                    VStack(alignment: .leading, spacing: 16) {
                        Text("Perlu bantuan apa?")
                            .font(.headline)
                            .padding(.horizontal)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(viewModel.services, id: \.self) { service in
                                    ServicePill(
                                        title: service,
                                        isSelected: viewModel.selectedService == service,
                                        action: { viewModel.selectService(service) }
                                    )
                                }
                            }
                            .padding(.horizontal)
                        }

                        if viewModel.requiresTireCount {
                            tireCountSection
                            photoSection
                        }

                        if viewModel.estimatedPrice > 0 {
                            HStack {
                                Text("Perkiraan Biaya")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("Rp\(viewModel.estimatedPrice)")
                                    .font(.headline)
                                    .fontWeight(.bold)
                            }
                            .padding(.horizontal)
                        }

                        PrimaryButton(
                            title: "Cari Bengkel",
                            iconName: "wrench.and.screwdriver.fill",
                            action: viewModel.createOrder
                        )
                        .disabled(isCreateDisabled)
                        .opacity(isCreateDisabled ? 0.5 : 1)
                        .padding(.horizontal)
                        .padding(.bottom, 12)
                    }
                    .padding(.top, 16)
                }
                .background(Color(.systemBackground))
            }

            // Back button (sibling: stays within the safe area, clear of the status bar)
            Button(action: {
                presentationMode.wrappedValue.dismiss()
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

            // Address search overlay (covers everything while editing the location)
            if viewModel.isEditingLocation {
                LocationSearchView(viewModel: viewModel)
                    .transition(.move(edge: .bottom))
                    .zIndex(2)
            }
        }
        .navigationDestination(isPresented: $viewModel.navigateToBidding) {
            if let serviceType = viewModel.pendingServiceType {
                CustomerBiddingView(
                    serviceType: serviceType,
                    coordinate: viewModel.region.center,
                    tireCount: viewModel.pendingTireCount,
                    photoUrl: viewModel.pendingPhotoUrl
                )
            }
        }
        .navigationBarHidden(true)
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: viewModel.isEditingLocation)
        .loadingOverlay(
            phase: viewModel.loadingPhase,
            onRetry: { viewModel.createOrder() },
            onStop: { viewModel.cancelLoading() }
        )
        .onAppear {
            if !didRequestInitialLocation {
                didRequestInitialLocation = true
                viewModel.useCurrentLocation()
            }
        }
        .onChange(of: selectedPhoto) { newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self) {
                    viewModel.photoData = data
                }
            }
        }
    }

    private var isCreateDisabled: Bool {
        if viewModel.selectedService == nil { return true }
        if viewModel.requiresTireCount && viewModel.photoData == nil { return true }
        return false
    }

    private var tireCountSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Berapa ban yang bermasalah?")
                .font(.subheadline)
                .foregroundColor(.secondary)
            HStack(spacing: 12) {
                ForEach(1...4, id: \.self) { count in
                    Button(action: { viewModel.setTireCount(count) }) {
                        Text("\(count)")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .foregroundColor(viewModel.tireCount == count ? Color(.systemBackground) : .primary)
                            .background(viewModel.tireCount == count ? Color.primary.opacity(0.9) : Color(.systemGray5))
                            .cornerRadius(12)
                    }
                }
            }
        }
        .padding(.horizontal)
    }

    private var photoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Foto kondisi ban")
                .font(.subheadline)
                .foregroundColor(.secondary)
            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                if let data = viewModel.photoData, let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 160)
                        .frame(maxWidth: .infinity)
                        .clipped()
                        .cornerRadius(12)
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "camera.fill")
                            .font(.title2)
                        Text("Tambahkan foto")
                            .font(.subheadline)
                    }
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 120)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
            }
        }
        .padding(.horizontal)
    }
}

#Preview {
    OrderView()
}
