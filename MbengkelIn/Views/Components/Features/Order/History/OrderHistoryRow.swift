//
//  OrderHistoryRow.swift
//  MbengkelIn
//
//  Created by Bryan Fernando Dinata on 28/05/26.
//

import SwiftUI

struct OrderHistoryRow: View {
    let order: NearbyOrder
    let onTap: () -> Void
    var onReport: (() -> Void)? = nil

    private var canReport: Bool {
        onReport != nil && (order.status == "Done" || order.status == "Cancelled")
    }

    var body: some View {
        VStack(spacing: 8) {
            Button(action: onTap) {
                card
            }
            .buttonStyle(.plain)

            if canReport {
                Button {
                    onReport?()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "flag.fill")
                        Text("Laporkan perilaku")
                    }
                    .font(.caption.bold())
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.red.opacity(0.10))
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var card: some View {
        HStack(spacing: 14) {
                Image(systemName: "wrench.and.screwdriver.fill")
                    .font(.title3)
                    .foregroundColor(.primary)
                    .frame(width: 46, height: 46)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 6) {
                    Text(order.serviceType ?? order.description ?? "Servis")
                        .font(.subheadline.bold())
                        .foregroundColor(.primary)
                    Text(String(order.createdAt?.prefix(10) ?? "-"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    if let info = order.vehicleInfo, !info.isEmpty {
                        Label(info, systemImage: "car.fill")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    if let rating = order.rating, rating > 0 {
                        StarRatingView(rating: Double(rating))
                            .frame(height: 12)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 6) {
                    OrderStatusBadge(status: order.status)
                    if let price = order.price, price > 0 {
                        Text(Rupiah.format(price))
                            .font(.caption.bold())
                            .foregroundColor(.primary)
                    }
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
        .overlay(alignment: .topTrailing) {
            if order.status == "On Progress" {
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundColor(.green)
                    .padding(10)
            }
        }
    }
}
