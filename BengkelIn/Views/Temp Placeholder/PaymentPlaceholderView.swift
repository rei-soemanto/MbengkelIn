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
            Text("Payment Management")
                .font(.title2)
                .fontWeight(.semibold)
                .padding(.top)
            Text("Top-up and balance history will be built by Bryan.")
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding()
        }
        .navigationTitle("Payment")
    }
}

// Bryan's Scope
struct HistoryPlaceholderView: View {
    var body: some View {
        NavigationStack {
            VStack {
                Image(systemName: "clock")
                    .font(.system(size: 50))
                    .foregroundColor(.blue)
                Text("Order History")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .padding(.top)
                Text("List of past services will be built by Bryan.")
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding()
            }
            .navigationTitle("History")
        }
    }
}
