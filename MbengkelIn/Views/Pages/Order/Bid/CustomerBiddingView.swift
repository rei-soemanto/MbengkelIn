//
//  CustomerBiddingView.swift
//  MbengkelIn
//
//  Created by Bryan Fernando Dinata on 19/05/26.
//

import SwiftUI
import CoreLocation

struct CustomerBiddingView: View {
    // Pops the whole order flow back to Beranda when the order is cancelled.
    var popToRoot: () -> Void = {}

    @StateObject private var viewModel: CustomerBiddingViewModel
    @Environment(\.dismiss) private var dismiss
    private let isResuming: Bool

    init(serviceType: ServiceType, coordinate: CLLocationCoordinate2D, tireCount: Int = 1, photoUrls: [String] = [], vehicleId: String? = nil, vehicleInfo: String? = nil, popToRoot: @escaping () -> Void = {}) {
        self.popToRoot = popToRoot
        self.isResuming = false
        _viewModel = StateObject(wrappedValue: CustomerBiddingViewModel(
            serviceType: serviceType,
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            tireCount: tireCount,
            photoUrls: photoUrls,
            vehicleId: vehicleId,
            vehicleInfo: vehicleInfo
        ))
    }

    init(resuming order: NearbyOrder, popToRoot: @escaping () -> Void = {}) {
        self.popToRoot = popToRoot
        self.isResuming = true
        _viewModel = StateObject(wrappedValue: CustomerBiddingViewModel(resuming: order))
    }

    var body: some View {
        VStack(spacing: 0) {
            if !viewModel.isSearching {
                BidPriceSetupView(
                    serviceType: viewModel.serviceType,
                    minPrice: viewModel.minPrice,
                    initialPrice: viewModel.customerBidPrice,
                    isStartingSearch: viewModel.isStartingSearch,
                    onSubmit: { price in
                        Task { await viewModel.startSearch(price: price) }
                    }
                )
                .id(viewModel.customerBidPrice)
            } else {
                ActiveBiddingView(viewModel: viewModel)
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(viewModel.isSearching ? "Mencari Bengkel" : "Atur Tawaran Anda")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    if viewModel.isSearching { popToRoot() } else { dismiss() }
                } label: {
                    Image(systemName: "chevron.left")
                        .fontWeight(.semibold)
                }
            }
        }
        .alert("Tidak Bisa Melanjutkan", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .navigationDestination(isPresented: Binding(
            get: { viewModel.acceptedBid != nil },
            set: { if !$0 { viewModel.acceptedBid = nil } }
        )) {
            if let bid = viewModel.acceptedBid {
                OrderTrackingView(
                    bid: bid,
                    customerCoordinate: CLLocationCoordinate2D(
                        latitude: viewModel.latitude,
                        longitude: viewModel.longitude
                    ),
                    popToRoot: popToRoot
                )
            }
        }
        .confirmationDialog(
            "Belum ada bengkel yang menawar",
            isPresented: $viewModel.showRetryPrompt,
            titleVisibility: .visible
        ) {
            Button("Naikkan harga tawaran") { viewModel.raisePrice() }
            Button("Coba lagi dengan harga sama") { viewModel.retrySamePrice() }
            Button("Batalkan pesanan", role: .destructive) {
                Task { await viewModel.cancel() }
            }
        } message: {
            Text("Pesanan akan dibatalkan otomatis dalam 10 detik jika tidak ada pilihan.")
        }
        .onChange(of: viewModel.shouldDismiss) { dismissNow in
            if dismissNow { popToRoot() }
        }
        .task {
            if isResuming { await viewModel.resume() }
        }
    }
}
