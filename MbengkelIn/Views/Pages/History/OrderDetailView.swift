//
//  OrderDetailView.swift
//  MbengkelIn
//
//  Created by Bryan Fernando Dinata on 28/05/26.
//

import SwiftUI
import MapKit
import CoreLocation

struct OrderDetailView: View {
    let order: NearbyOrder

    @State private var region: MKCoordinateRegion

    init(order: NearbyOrder) {
        self.order = order
        _region = State(initialValue: MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: order.latitude, longitude: order.longitude),
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        ))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Map(coordinateRegion: .constant(region), annotationItems: [order]) { item in
                    MapMarker(coordinate: CLLocationCoordinate2D(
                        latitude: item.latitude,
                        longitude: item.longitude
                    ))
                }
                .frame(height: 220)
                .cornerRadius(16)
                .allowsHitTesting(false)

                detailCard
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Detail Pesanan")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var detailCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(order.serviceType ?? order.description ?? "Servis")
                    .font(.title3.bold())
                Spacer()
                OrderStatusBadge(status: order.status)
            }

            Divider()

            detailRow(label: "Harga", value: order.price.map { Rupiah.format($0) } ?? "-")
            detailRow(label: "Tanggal", value: String(order.createdAt?.prefix(10) ?? "-"))
            detailRow(label: "Darurat", value: (order.isEmergency ?? false) ? "Ya" : "Tidak")
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 3)
    }

    private func detailRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
        }
        .font(.subheadline)
    }
}
