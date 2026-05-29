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

    var body: some View {
        ZStack(alignment: .topLeading) {
            VStack(spacing: 0) {
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
                            TirePhotoGrid(count: viewModel.tireCount, photos: $viewModel.photosData)
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
                    photoUrls: viewModel.pendingPhotoUrls
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
            // Start every order fresh: clear stale state and re-acquire the
            // current location so an order can't inherit a previous order's
            // coordinate (or the hard-coded default).
            guard !viewModel.navigateToBidding else { return }
            viewModel.prepareForNewOrder()
            viewModel.useCurrentLocation()
        }
    }

    private var isCreateDisabled: Bool {
        if viewModel.selectedService == nil { return true }
        if !viewModel.hasResolvedLocation { return true }
        if viewModel.requiresTireCount {
            let provided = viewModel.photosData.prefix(viewModel.tireCount).compactMap { $0 }
            if provided.count < viewModel.tireCount { return true }
        }
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
}

#Preview {
    OrderView()
}
