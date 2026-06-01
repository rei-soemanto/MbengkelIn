//
//  ActiveBiddingView.swift
//  MbengkelIn
//
//  Created by Bryan Fernando Dinata on 19/05/26.
//

import SwiftUI
import CoreLocation

struct ActiveBiddingView: View {
    @ObservedObject var viewModel: CustomerBiddingViewModel
    @State private var showCancelConfirm = false

    private var customerCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: viewModel.latitude, longitude: viewModel.longitude)
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if viewModel.bids.isEmpty {
                        BiddingWaitingState(isAnimating: viewModel.isLoading)
                    } else {
                        bidsSection
                    }
                }
            }
            .refreshable {
                await viewModel.refresh()
            }

            if viewModel.bids.isEmpty {
                SearchCountdownBar(
                    secondsRemaining: viewModel.searchSecondsRemaining,
                    progress: viewModel.searchProgress
                )
            }

            Button(role: .destructive) {
                showCancelConfirm = true
            } label: {
                Text("Batalkan Pesanan")
                    .font(.headline)
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color(.systemBackground))
            }
            .confirmationDialog(
                "Batalkan pesanan ini?",
                isPresented: $showCancelConfirm,
                titleVisibility: .visible
            ) {
                Button("Ya, batalkan", role: .destructive) {
                    Task { await viewModel.cancel() }
                }
                Button("Tidak", role: .cancel) {}
            }
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Tawaran Aktif Anda")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                Text(Rupiah.format(viewModel.customerBidPrice))
                    .font(.title2)
                    .fontWeight(.bold)
            }
            Spacer()

            Button(action: {
                viewModel.stopRealtimeSubscription()
                viewModel.isSearching = false
            }) {
                Text("Ubah Harga")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color(.systemBackground))
                    .cornerRadius(8)
                    .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }

    private var bidsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Tawaran Masuk")
                    .font(.title3)
                    .fontWeight(.bold)
                Spacer()
                Text("\(viewModel.bids.count) Tawaran")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(.systemGray5))
                    .cornerRadius(6)
            }
            .padding(.horizontal)
            .padding(.top, 16)

            ForEach(viewModel.bids) { bid in
                BidReceivedCard(
                    bid: bid,
                    customerCoordinate: customerCoordinate,
                    onAccept: {
                        Task { await viewModel.acceptBid(bid) }
                    },
                    onReject: {
                        Task { await viewModel.rejectBid(bid) }
                    }
                )
                .padding(.horizontal)
            }
        }
    }
}
