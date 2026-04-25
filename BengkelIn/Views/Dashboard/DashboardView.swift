//
//  DashboardView.swift
//  BengkelIn
//
//  Created by Rei Soemanto on 23/04/26.
//

import SwiftUI

struct DashboardView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @State private var recentOrders: [String] = []
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if authViewModel.currentUser?.role == "PROVIDER" {
                    Picker("App Mode", selection: $authViewModel.appMode) {
                        Text("Customer").tag(AppMode.customer)
                        Text("Bengkel").tag(AppMode.bengkel)
                    }
                    .pickerStyle(.segmented)
                    .padding()
                }
                
                if authViewModel.appMode == .customer || authViewModel.currentUser?.role != "PROVIDER" {
                    customerDashboard
                } else {
                    BengkelDashboardView(authViewModel: authViewModel)
                }
            }
        }
    }
    
    private var customerDashboard: some View {
        ScrollView {
            VStack(spacing: 24) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("BengkelIn")
                            .font(.title3)
                            .foregroundColor(.gray)
                        Text("Hi, \(authViewModel.currentUser?.name ?? "User")!")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                    }
                    Spacer()
                }

                Button {
                    // LINK CREATE ORDER PAGE
                } label: {
                    HStack {
                        Image(systemName: "wrench.and.screwdriver.fill")
                            .font(.largeTitle)
                        Text("Create Order")
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

                NavigationLink(destination: Text("Payment Placeholder")) {
                    HStack {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("My Balance")
                                .font(.subheadline)
                                .foregroundColor(Color(.systemBackground).opacity(0.8))
                            
                            Text(formatToRupiah(authViewModel.currentUser?.balance ?? 0.0))
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
                    Text("Latest Orders")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    if recentOrders.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "doc.text.magnifyingglass")
                                .font(.largeTitle)
                                .foregroundColor(.gray)
                            Text("No order yet")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 30)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    } else {
                        ForEach(recentOrders.prefix(3), id: \.self) { order in
                            Text("Order Data Here")
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                Spacer()
            }
            .padding()
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

#Preview("Light Theme") {
    DashboardView(
        authViewModel: AuthViewModel()
    )
    .preferredColorScheme(.light)
}

#Preview("Dark Theme") {
    DashboardView(
        authViewModel: AuthViewModel()
    )
    .preferredColorScheme(.dark)
}
