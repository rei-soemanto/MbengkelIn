//
//  CustomerHistoryView.swift
//  MbengkelIn
//
//  Created by Bryan Fernando Dinata on 28/05/26.
//

import SwiftUI
import CoreLocation

struct CustomerHistoryView: View {
    @StateObject private var viewModel = HistoryViewModel()

    var body: some View {
        content
            .background(Color(.systemGroupedBackground))
            .task { await viewModel.loadOrders() }
            .refreshable { await viewModel.loadOrders() }
            .navigationDestination(isPresented: detailBinding) {
                if let order = viewModel.detailOrder {
                    OrderDetailView(order: order, isCustomer: true)
                }
            }
            .navigationDestination(isPresented: trackingBinding) {
                if let bid = viewModel.trackingBid,
                   let coordinate = viewModel.trackingCoordinate {
                    OrderTrackingView(bid: bid, customerCoordinate: coordinate)
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.orders.isEmpty {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if viewModel.orders.isEmpty {
            HistoryEmptyState(message: "Riwayat pesanan kamu akan muncul di sini.")
        } else {
            orderList
        }
    }

    private var orderList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(viewModel.orders) { order in
                    OrderHistoryRow(order: order) {
                        Task { await viewModel.select(order) }
                    }
                }
            }
            .padding()
        }
    }

    private var detailBinding: Binding<Bool> {
        Binding(
            get: { viewModel.detailOrder != nil },
            set: { if !$0 { viewModel.detailOrder = nil } }
        )
    }

    private var trackingBinding: Binding<Bool> {
        Binding(
            get: { viewModel.trackingBid != nil },
            set: { if !$0 { viewModel.trackingBid = nil; viewModel.trackingCoordinate = nil } }
        )
    }
}
