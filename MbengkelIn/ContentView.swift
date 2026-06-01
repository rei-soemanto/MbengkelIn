//
//  ContentView.swift
//  MbengkelIn
//
//  Created by Rei Soemanto on 23/04/26.
//

import SwiftUI
import Supabase

struct ContentView: View {
    @StateObject private var authViewModel = AuthViewModel()
    @StateObject private var network = NetworkMonitor()
    @StateObject private var bengkelBiddingViewModel = BengkelBiddingViewModel()
    @State private var bidOrder: NearbyOrder?
    @Environment(\.scenePhase) private var scenePhase

    private var isProvider: Bool { authViewModel.currentUser?.role == "PROVIDER" }
    private var isBengkelMode: Bool { isProvider && authViewModel.appMode == .bengkel }

    var body: some View {
        Group {
            if !network.isConnected {
                OfflineView {
                    Task { await authViewModel.loadInitialSession() }
                }
            } else if authViewModel.isInitializing {
                SplashView()
            } else if authViewModel.userSession != nil {
                VStack(spacing: 0) {
                    if isProvider {
                        Picker("App Mode", selection: $authViewModel.appMode) {
                            Text("Pelanggan").tag(AppMode.customer)
                            Text("Bengkel").tag(AppMode.bengkel)
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .background(Color(.systemBackground))
                    }

                    mainTabView
                }
            } else {
                LoginView(authViewModel: authViewModel)
            }
        }
        .tint(.primary)
        .onChange(of: scenePhase) { phase in
            if phase == .active {
                Task { await bengkelBiddingViewModel.refreshOnForeground() }
            }
        }
        .onChange(of: network.isConnected) { connected in
            if connected {
                Task { await authViewModel.loadInitialSession() }
            }
        }
        .task(id: authViewModel.userSession?.id) {
            if let uid = authViewModel.userSession?.id.uuidString.lowercased() {
                WatchSessionManager.shared.startObserving(customerId: uid)
            } else {
                WatchSessionManager.shared.stop()
            }
        }
    }

    private var mainTabView: some View {
        TabView {
            DashboardView(authViewModel: authViewModel, bengkelBiddingViewModel: bengkelBiddingViewModel)
                .tabItem {
                    Label(
                        isBengkelMode ? "Bengkel" : "Beranda",
                        systemImage: isBengkelMode ? "wrench.and.screwdriver.fill" : "house.fill"
                    )
                }

            PaymentView()
                .tabItem {
                    Label(
                        isBengkelMode ? "Pendapatan" : "Saldo",
                        systemImage: isBengkelMode ? "banknote.fill" : "creditcard.fill"
                    )
                }

            HistoryView(authViewModel: authViewModel)
                .tabItem {
                    Label(
                        isBengkelMode ? "Pesanan" : "Riwayat",
                        systemImage: isBengkelMode ? "list.bullet.rectangle.portrait.fill" : "clock.fill"
                    )
                }

            ProfileView(authViewModel: authViewModel)
                .tabItem {
                    Label(
                        "Profil",
                        systemImage: isBengkelMode ? "person.crop.square.fill" : "person.fill"
                    )
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
        .fullScreenCover(item: $bengkelBiddingViewModel.activeBengkelOrder) { order in
            NavigationStack {
                BengkelRouteView(order: order)
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
        .alert(
            "Waktu Order Habis",
            isPresented: Binding(
                get: { bengkelBiddingViewModel.expiredBidAlert != nil },
                set: { if !$0 { bengkelBiddingViewModel.expiredBidAlert = nil } }
            )
        ) {
            Button("OK", role: .cancel) { bengkelBiddingViewModel.expiredBidAlert = nil }
        } message: {
            Text(bengkelBiddingViewModel.expiredBidAlert ?? "")
        }
        .alert(
            "Tawaran Ditolak",
            isPresented: Binding(
                get: { bengkelBiddingViewModel.rejectedBidAlert != nil },
                set: { if !$0 { bengkelBiddingViewModel.rejectedBidAlert = nil } }
            )
        ) {
            Button("OK", role: .cancel) { bengkelBiddingViewModel.rejectedBidAlert = nil }
        } message: {
            Text(bengkelBiddingViewModel.rejectedBidAlert ?? "")
        }
        .alert(
            "Order Dibatalkan",
            isPresented: Binding(
                get: { bengkelBiddingViewModel.orderUnavailableAlert != nil },
                set: { if !$0 { bengkelBiddingViewModel.orderUnavailableAlert = nil } }
            )
        ) {
            Button("OK", role: .cancel) { bengkelBiddingViewModel.orderUnavailableAlert = nil }
        } message: {
            Text(bengkelBiddingViewModel.orderUnavailableAlert ?? "")
        }
    }
}

struct SplashView: View {
    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Image(systemName: "wrench.and.screwdriver.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.primary)

                Text("MbengkelIn")
                    .font(.title.bold())
                    .foregroundStyle(.primary)

                ProgressView()
                    .padding(.top, 8)
            }
        }
    }
}

#Preview {
    ContentView()
}
