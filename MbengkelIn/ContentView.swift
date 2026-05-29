//
//  ContentView.swift
//  MbengkelIn
//
//  Created by Rei Soemanto on 23/04/26.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var authViewModel = AuthViewModel()
    @StateObject private var bengkelBiddingViewModel = BengkelBiddingViewModel()
    @State private var bidOrder: NearbyOrder?

    var body: some View {
        Group {
            if authViewModel.userSession != nil {
                TabView {
                    DashboardView(authViewModel: authViewModel, bengkelBiddingViewModel: bengkelBiddingViewModel)
                        .tabItem {
                            Label("Dashboard", systemImage: "house.fill")
                        }
                    
                    PaymentView()
                        .tabItem {
                            Label("Payment", systemImage: "creditcard.fill")
                        }
                    
                    HistoryView(authViewModel: authViewModel)
                        .tabItem {
                            Label("History", systemImage: "clock.fill")
                        }
                    
                    ProfileView(authViewModel: authViewModel)
                        .tabItem {
                            Label("Profile", systemImage: "person.fill")
                        }
                }
                .task(id: authViewModel.currentUser?.role) {
                    if authViewModel.currentUser?.role == "PROVIDER" {
                        await bengkelBiddingViewModel.start()
                    }
                }
                .sheet(item: $bengkelBiddingViewModel.newOrderAlert) { order in
                    IncomingJobModal(
                        order: order,
                        onBid: {
                            bengkelBiddingViewModel.newOrderAlert = nil
                            bidOrder = order
                        },
                        onDismiss: { bengkelBiddingViewModel.newOrderAlert = nil }
                    )
                    .presentationDetents([.medium])
                }
                .sheet(item: $bidOrder) { order in
                    PlaceBidSheet(minPrice: order.price ?? 0) { price, notes in
                        Task { await bengkelBiddingViewModel.placeBid(order: order, price: price, notes: notes) }
                    }
                }
                .alert(
                    "Order Diambil",
                    isPresented: Binding(
                        get: { bengkelBiddingViewModel.lostBidAlert != nil },
                        set: { if !$0 { bengkelBiddingViewModel.lostBidAlert = nil } }
                    )
                ) {
                    Button("OK", role: .cancel) { bengkelBiddingViewModel.lostBidAlert = nil }
                } message: {
                    Text(bengkelBiddingViewModel.lostBidAlert ?? "")
                }
            } else {
                LoginView(authViewModel: authViewModel)
            }
        }
        .tint(.primary)
    }
}

#Preview {
    ContentView()
}
