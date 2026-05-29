//
//  DashboardView.swift
//  MbengkelIn
//
//  Created by Rei Soemanto on 23/04/26.
//

import SwiftUI

// Routes pushed onto the customer dashboard's navigation stack. Driving the
// order flow through a path (rather than a plain NavigationLink) lets the
// bidding screen pop all the way back to Beranda when an order is cancelled.
enum DashboardRoute: Hashable {
    case createOrder
}

struct DashboardView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @ObservedObject var bengkelBiddingViewModel: BengkelBiddingViewModel
    @State private var recentOrders: [String] = []
    @State private var path = NavigationPath()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: 0) {
                if authViewModel.appMode == .customer || authViewModel.currentUser?.role != "PROVIDER" {
                    customerDashboard
                } else {
                    BengkelDashboardView(authViewModel: authViewModel, bengkelBiddingViewModel: bengkelBiddingViewModel)
                }
            }
            .navigationDestination(for: DashboardRoute.self) { route in
                switch route {
                case .createOrder:
                    OrderView(popToRoot: { path = NavigationPath() })
                }
            }
            .task { await authViewModel.fetchUser() }
            .onChange(of: scenePhase) { phase in
                if phase == .active { Task { await authViewModel.fetchUser() } }
            }
        }
    }
    
    private var customerDashboard: some View {
        ScrollView {
            VStack(spacing: 24) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("MbengkelIn")
                            .font(.title3)
                            .foregroundColor(.gray)
                        Text("Hi, \(authViewModel.currentUser?.name ?? "User")!")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                    }
                    Spacer()
                }

                NavigationLink(value: DashboardRoute.createOrder) {
                                    HStack {
                                        Image(systemName: "wrench.and.screwdriver.fill")
                                            .font(.largeTitle)
                                        Text("Buat Pesanan")
                                            .font(.title)
                                            .fontWeight(.bold)
                                    }
                                    .foregroundColor(Color(.systemBackground))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 120)
                                    .background(Color.primary.opacity(0.9))
                                    .cornerRadius(16)
                                    .shadow(color: Color.primary.opacity(0.15), radius: 10, x: 0, y: 5)
                                }

                NavigationLink(destination: Text("Pembayaran Sementara")) {
                    HStack {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Saldo Saya")
                                .font(.subheadline)
                                .foregroundColor(Color(.systemBackground).opacity(0.8))
                            
                            Text(Rupiah.format(authViewModel.currentUser?.balance ?? 0.0))
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(Color(.systemBackground))
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(Color(.systemBackground).opacity(0.8))
                    }
                    .padding()
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.primary.opacity(0.9),
                                Color.primary.opacity(0.75)
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(16)
                    .shadow(color: Color.primary.opacity(0.15), radius: 10, x: 0, y: 5)
                }
                
                VStack(alignment: .leading, spacing: 16) {
                    Text("Pesanan Terbaru")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    if recentOrders.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "doc.text.magnifyingglass")
                                .font(.largeTitle)
                                .foregroundColor(.gray)
                            Text("Belum ada pesanan")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 30)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    } else {
                        ForEach(recentOrders.prefix(3), id: \.self) { order in
                            Text("Data Pesanan di Sini")
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                Spacer()
            }
            .padding()
        }
    }
}

#Preview("Light Theme") {
    DashboardView(
        authViewModel: AuthViewModel(),
        bengkelBiddingViewModel: BengkelBiddingViewModel()
    )
    .preferredColorScheme(.light)
}

#Preview("Dark Theme") {
    DashboardView(
        authViewModel: AuthViewModel(),
        bengkelBiddingViewModel: BengkelBiddingViewModel()
    )
    .preferredColorScheme(.dark)
}
