//
//  TrackingInfoCard.swift
//  MbengkelIn
//
//  Created by Bryan Fernando Dinata on 19/05/26.
//

import SwiftUI

struct TrackingInfoCard: View {
    let bid: Bid
    let isLive: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "wrench.and.screwdriver.fill")
                    .font(.title2).foregroundColor(.white)
                    .padding(12).background(Color.primary).clipShape(Circle())
                VStack(alignment: .leading, spacing: 4) {
                    Text(bid.bengkel?.name ?? "Bengkel").font(.headline.bold())
                    Text(bid.bengkel?.address ?? "")
                        .font(.caption).foregroundColor(.secondary).lineLimit(2)
                }
                Spacer()
                NavigationLink(destination: ChatView(serviceRequestId: bid.serviceRequestId, title: bid.bengkel?.name ?? "Bengkel")) {
                    Image(systemName: "message.fill")
                        .font(.title3)
                        .foregroundColor(.primary)
                        .padding(12)
                        .background(Color(.systemGray6))
                        .clipShape(Circle())
                }
            }
            Divider()
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Harga Disepakati").font(.caption)
                        .foregroundColor(.secondary).textCase(.uppercase)
                    Text(Rupiah.format(bid.price)).font(.title3.bold())
                }
                Spacer()
                Label(
                    isLive ? "Lokasi langsung" : "Sedang menuju",
                    systemImage: isLive ? "dot.radiowaves.left.and.right" : "location.circle.fill"
                )
                .font(.caption).foregroundColor(.green)
            }
            CompleteOrderButton(requestId: bid.serviceRequestId, isCustomer: true)
        }
        .padding()
        .background(Color(.systemBackground))
        .shadow(color: .black.opacity(0.05), radius: 10, y: -2)
    }
}
