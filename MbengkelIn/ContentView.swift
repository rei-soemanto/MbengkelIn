//
//  ContentView.swift
//  MbengkelIn
//
//  Created by Rei Soemanto on 23/04/26.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var authViewModel = AuthViewModel()
    // Watches for incoming jobs at the root so a provider gets alerted on any
    // tab (not just while the Bengkel dashboard is on screen).
    @StateObject private var mechanicViewModel = MechanicBiddingViewModel()
    @State private var bidOrder: NearbyOrder?

    var body: some View {
        Group {
            if authViewModel.userSession != nil {
                TabView {
                    DashboardView(authViewModel: authViewModel, mechanicViewModel: mechanicViewModel)
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
                        await mechanicViewModel.start()
                    }
                }
                .sheet(item: $mechanicViewModel.newOrderAlert) { order in
                    IncomingJobModal(
                        order: order,
                        onBid: {
                            mechanicViewModel.newOrderAlert = nil
                            bidOrder = order
                        },
                        onDismiss: { mechanicViewModel.newOrderAlert = nil }
                    )
                    .presentationDetents([.medium])
                }
                .sheet(item: $bidOrder) { order in
                    PlaceBidSheet(minPrice: order.price ?? 0) { price, notes in
                        Task { await mechanicViewModel.placeBid(order: order, price: price, notes: notes) }
                    }
                }
                .alert(
                    "Order Diambil",
                    isPresented: Binding(
                        get: { mechanicViewModel.lostBidAlert != nil },
                        set: { if !$0 { mechanicViewModel.lostBidAlert = nil } }
                    )
                ) {
                    Button("OK", role: .cancel) { mechanicViewModel.lostBidAlert = nil }
                } message: {
                    Text(mechanicViewModel.lostBidAlert ?? "")
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
