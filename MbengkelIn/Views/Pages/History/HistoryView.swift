//
//  HistoryView.swift
//  MbengkelIn
//
//  Created by Bryan Fernando Dinata on 28/05/26.
//

import SwiftUI

struct HistoryView: View {
    @ObservedObject var authViewModel: AuthViewModel

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
                    CustomerHistoryView()
                } else {
                    BengkelHistoryView()
                }
            }
            .navigationTitle("Riwayat Pesanan")
            .background(Color(.systemGroupedBackground))
        }
    }
}

#Preview {
    HistoryView(authViewModel: AuthViewModel())
}
