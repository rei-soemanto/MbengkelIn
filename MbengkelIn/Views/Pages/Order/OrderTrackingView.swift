//
//  OrderTrackingView.swift
//  MbengkelIn
//

import SwiftUI
import MapKit
import CoreLocation

struct TrackingPin: Identifiable {
    let id: String
    let coordinate: CLLocationCoordinate2D
    let label: String
    let icon: String
    let tint: Color
}

struct OrderTrackingView: View {
    let bid: Bid
    let customerCoordinate: CLLocationCoordinate2D

    @State private var region: MKCoordinateRegion

    init(bid: Bid, customerCoordinate: CLLocationCoordinate2D) {
        self.bid = bid
        self.customerCoordinate = customerCoordinate
        let bLat = bid.bengkel?.latitude ?? customerCoordinate.latitude
        let bLon = bid.bengkel?.longitude ?? customerCoordinate.longitude
        let midLat = (customerCoordinate.latitude + bLat) / 2
        let midLon = (customerCoordinate.longitude + bLon) / 2
        let latSpan = abs(customerCoordinate.latitude - bLat) * 2.5 + 0.01
        let lonSpan = abs(customerCoordinate.longitude - bLon) * 2.5 + 0.01
        _region = State(initialValue: MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: midLat, longitude: midLon),
            span: MKCoordinateSpan(latitudeDelta: latSpan, longitudeDelta: lonSpan)
        ))
    }

    var body: some View {
        VStack(spacing: 0) {
            Map(coordinateRegion: $region, annotationItems: pins) { item in
                MapAnnotation(coordinate: item.coordinate) {
                    VStack(spacing: 2) {
                        Image(systemName: item.icon)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.white)
                            .padding(10)
                            .background(item.tint)
                            .clipShape(Circle())
                        Text(item.label)
                            .font(.caption2.bold())
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Color(.systemBackground))
                            .cornerRadius(6)
                    }
                }
            }
            infoCard
        }
        .navigationTitle("Mechanic Menuju Lokasi")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
    }

    private var infoCard: some View {
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
                NavigationLink(destination: ChatView(bengkel: bid.bengkel)) {
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
                    Text(formatRupiah(bid.price)).font(.title3.bold())
                }
                Spacer()
                Label("Sedang menuju", systemImage: "location.circle.fill")
                    .font(.caption).foregroundColor(.green)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .shadow(color: .black.opacity(0.05), radius: 10, y: -2)
    }

    private var pins: [TrackingPin] {
        var list = [TrackingPin(id: "you", coordinate: customerCoordinate,
                                label: "Anda", icon: "person.fill", tint: .blue)]
        if let lat = bid.bengkel?.latitude, let lon = bid.bengkel?.longitude {
            list.append(TrackingPin(
                id: "bengkel",
                coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                label: bid.bengkel?.name ?? "Bengkel",
                icon: "wrench.and.screwdriver.fill",
                tint: .primary))
        }
        return list
    }

    private func formatRupiah(_ amount: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency; f.currencyCode = "IDR"
        f.locale = Locale(identifier: "id_ID"); f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: amount)) ?? "Rp 0"
    }
}

#Preview {
    let bengkel = Bengkel(
        id: "preview-bengkel",
        providerUid: "preview-provider",
        name: "Bengkel Jaya Motor",
        address: "Jl. Raya Darmo No. 12, Surabaya",
        latitude: -7.2905,
        longitude: 112.6360,
        status: "Verified",
        offeredServices: [],
        averageRating: 4.8,
        totalReviews: 132
    )
    let bid = Bid(
        id: "preview-bid",
        serviceRequestId: "preview-request",
        providerUid: "preview-provider",
        bengkelId: "preview-bengkel",
        price: 75000,
        notes: "Segera meluncur ke lokasi Anda.",
        status: "Accepted",
        createdAt: nil,
        bengkel: bengkel
    )
    NavigationStack {
        OrderTrackingView(
            bid: bid,
            customerCoordinate: CLLocationCoordinate2D(latitude: -7.2845, longitude: 112.6315)
        )
    }
}
