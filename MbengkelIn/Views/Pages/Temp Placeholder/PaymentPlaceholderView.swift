//
//  PaymentPlaceholderView.swift
//  BengkelIn
//
//  Created by Rei Soemanto on 23/04/26.
//


import SwiftUI

// Bryan's Scope
struct PaymentPlaceholderView: View {
    var body: some View {
        VStack {
            Image(systemName: "creditcard")
                .font(.system(size: 50))
                .foregroundColor(.blue)
            Text("Manajemen Pembayaran")
                .font(.title2)
                .fontWeight(.semibold)
                .padding(.top)
            Text("Riwayat top up dan saldo akan dibuat oleh Bryan.")
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding()
        }
        .navigationTitle("Pembayaran")
    }
}
