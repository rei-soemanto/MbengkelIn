//
//  BengkelDashboardView.swift
//  MbengkelIn
//
//  Created by Rei Soemanto on 25/04/26.
//

import SwiftUI

struct BengkelDashboardView: View {
    @ObservedObject var authViewModel: AuthViewModel
    // Shared with ContentView so watching/notifications run regardless of tab.
    @ObservedObject var bengkelBiddingViewModel: BengkelBiddingViewModel

    @StateObject private var bengkelViewModel = BengkelViewModel()

    @State private var todaysEarnings: Double = 0.0
    @State private var selectedOrder: NearbyOrder?

    var realShopRating: Double {
        bengkelViewModel.myBengkel?.averageRating ?? 0.0
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {

                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Dasbor Penyedia")
                            .font(.title3)
                            .foregroundColor(.gray)
                        Text(bengkelViewModel.myBengkel?.name ?? "Manage Your Shop")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                    }
                    Spacer()
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Penilaian Bengkel")
                        .font(.subheadline)
                        .foregroundColor(.gray)

                    if bengkelViewModel.isLoading && bengkelViewModel.myBengkel == nil {
                        ProgressView()
                    } else {
                        HStack(spacing: 12) {
                            Text(String(format: "%.1f", realShopRating))
                                .font(.title)
                                .fontWeight(.bold)

                            StarRatingView(rating: realShopRating)

                            Spacer()

                            Text("(\(bengkelViewModel.myBengkel?.totalReviews ?? 0) Ulasan)")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemGray6))
                .cornerRadius(12)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Pendapatan Hari Ini")
                        .font(.subheadline)
                        .foregroundColor(.gray)

                    HStack {
                        Image(systemName: "banknote.fill")
                            .foregroundColor(.green)
                            .font(.title2)

                        Text(formatToRupiah(todaysEarnings))
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)

                        Spacer()
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemGray6))
                .cornerRadius(12)

                NavigationLink(destination: BengkelBiddingView(viewModel: bengkelBiddingViewModel)) {
                    HStack {
                        Image(systemName: "list.bullet.rectangle.portrait.fill")
                            .font(.title2)
                        Text("Lihat Order Masuk")
                            .font(.headline)
                            .fontWeight(.bold)
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                    .foregroundColor(Color(.systemBackground))
                    .padding()
                    .background(Color.primary.opacity(0.9))
                    .cornerRadius(12)
                }

                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Permintaan Masuk")
                            .font(.title2)
                            .fontWeight(.bold)

                        Spacer()

                        if !bengkelBiddingViewModel.orders.isEmpty {
                            Text("\(bengkelBiddingViewModel.orders.count) Pending")
                                .font(.subheadline)
                                .foregroundColor(.red)
                                .fontWeight(.semibold)
                        }
                    }

                    if bengkelBiddingViewModel.orders.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.largeTitle)
                                .foregroundColor(.gray)
                            Text("Tidak ada permintaan masuk")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 30)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    } else {
                        ForEach(bengkelBiddingViewModel.orders.prefix(3)) { order in
                            let pendingBid = bengkelBiddingViewModel.myPendingBids.first(where: { $0.serviceRequestId == order.id })
                            OrderRequestCard(
                                order: order,
                                pendingBid: pendingBid,
                                onBid: { selectedOrder = order },
                                onExpire: {
                                    Task { await bengkelBiddingViewModel.handleExpiredOrder(order) }
                                }
                            )
                        }
                    }
                }

                Spacer()
            }
            .padding()
        }
        .task {
            if let uid = authViewModel.currentUser?.id {
                await bengkelViewModel.startWatching(uid: uid)
            }
        }
        .onDisappear {
            bengkelViewModel.stopWatching()
        }
        .sheet(item: $selectedOrder) { order in
            PlaceBidSheet(minPrice: order.price ?? 0) { price, notes in
                Task { await bengkelBiddingViewModel.placeBid(order: order, price: price, notes: notes) }
            }
        }
    }

    private func formatToRupiah(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "IDR"
        formatter.locale = Locale(identifier: "id_ID")
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "Rp 0"
    }
}

#Preview ("Light Mode") {
    BengkelDashboardView(authViewModel: AuthViewModel(), bengkelBiddingViewModel: BengkelBiddingViewModel())
        .preferredColorScheme(.light)
}

#Preview ("Dark Mode") {
    BengkelDashboardView(authViewModel: AuthViewModel(), bengkelBiddingViewModel: BengkelBiddingViewModel())
        .preferredColorScheme(.dark)
}
