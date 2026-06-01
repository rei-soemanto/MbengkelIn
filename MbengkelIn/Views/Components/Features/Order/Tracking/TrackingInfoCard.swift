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
    var status: String = "On Progress"
    var unreadCount: Int = 0
    var onOpenChat: () -> Void = {}
    var canComplete: Bool = true
    var onCancel: () -> Void = {}

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
                        .overlay(alignment: .topTrailing) {
                            UnreadBadge(count: unreadCount)
                        }
                }
                .simultaneousGesture(TapGesture().onEnded { onOpenChat() })
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
            if status == "On Progress" {
                CompleteOrderButton(requestId: bid.serviceRequestId, isCustomer: true, canComplete: canComplete)
                Button(role: .destructive) {
                    onCancel()
                } label: {
                    Text("Batalkan Pesanan")
                        .font(.subheadline.bold())
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.red.opacity(0.12))
                        .cornerRadius(16)
                }
            } else {
                statusLine
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .shadow(color: .black.opacity(0.05), radius: 10, y: -2)
    }

    @ViewBuilder
    private var statusLine: some View {
        let isCancelled = status == "Cancelled"
        HStack(spacing: 8) {
            Image(systemName: isCancelled ? "xmark.seal.fill" : "checkmark.seal.fill")
            Text(isCancelled ? "Pesanan dibatalkan." : "Pesanan selesai.")
                .fontWeight(.semibold)
            Spacer()
        }
        .font(.subheadline)
        .foregroundColor(isCancelled ? .red : .green)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background((isCancelled ? Color.red : Color.green).opacity(0.12))
        .cornerRadius(12)
    }
}
