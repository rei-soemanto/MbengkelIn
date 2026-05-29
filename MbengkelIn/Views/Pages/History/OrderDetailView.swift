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
    let isCustomer: Bool

    @StateObject private var ratingViewModel = OrderRatingViewModel()
    @StateObject private var locationPublisher = LocationPublishViewModel()
    @State private var region: MKCoordinateRegion

    // Local copies so the view reflects a freshly-submitted rating without a refetch.
    @State private var localRating: Int?
    @State private var localReview: String?
    @State private var selectedRating: Int = 0
    @State private var reviewText: String = ""

    init(order: NearbyOrder, isCustomer: Bool = false) {
        self.order = order
        self.isCustomer = isCustomer
        _region = State(initialValue: MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: order.latitude, longitude: order.longitude),
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        ))
        _localRating = State(initialValue: order.rating)
        _localReview = State(initialValue: order.review)
    }

    private var hasRating: Bool { (localRating ?? 0) > 0 }
    private var canRate: Bool { isCustomer && order.status == "Done" && !hasRating }
    // The assigned bengkel broadcasts its live location while the order is active.
    private var shouldPublishLocation: Bool { !isCustomer && order.status == "On Progress" }

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

                if canRate {
                    ratingInputCard
                }

                if order.status == "On Progress" {
                    NavigationLink(destination: ChatView(serviceRequestId: order.id, title: order.customerName ?? "Pelanggan")) {
                        HStack {
                            Image(systemName: "message.fill")
                            Text("Chat dengan Pelanggan").fontWeight(.bold)
                            Spacer()
                            Image(systemName: "chevron.right")
                        }
                        .foregroundColor(Color(.systemBackground))
                        .padding()
                        .background(Color.primary.opacity(0.9))
                        .cornerRadius(12)
                    }
                    CompleteOrderButton(requestId: order.id, isCustomer: isCustomer)
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Detail Pesanan")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Terjadi Kesalahan", isPresented: Binding(
            get: { ratingViewModel.errorMessage != nil },
            set: { if !$0 { ratingViewModel.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { ratingViewModel.errorMessage = nil }
        } message: {
            Text(ratingViewModel.errorMessage ?? "")
        }
        .onAppear {
            if shouldPublishLocation {
                locationPublisher.start(
                    serviceRequestId: order.id,
                    customerCoordinate: CLLocationCoordinate2D(
                        latitude: order.latitude,
                        longitude: order.longitude
                    )
                )
            }
        }
        .onDisappear { locationPublisher.stop() }
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
            if let info = order.vehicleInfo, !info.isEmpty {
                detailRow(label: "Kendaraan", value: info)
            }

            if let rating = localRating, rating > 0 {
                Divider()
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Penilaian")
                            .foregroundColor(.secondary)
                        Spacer()
                        StarRatingView(rating: Double(rating))
                            .frame(height: 16)
                    }
                    .font(.subheadline)
                    if let review = localReview, !review.isEmpty {
                        Text(review)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 3)
    }

    private var ratingInputCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Beri Penilaian")
                .font(.headline)
            Text("Bagaimana layanan bengkel ini?")
                .font(.subheadline)
                .foregroundColor(.secondary)

            HStack {
                Spacer()
                InteractiveStarRating(rating: $selectedRating)
                Spacer()
            }

            TextField("Tulis ulasan (opsional)", text: $reviewText, axis: .vertical)
                .lineLimit(3...6)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)

            Button {
                Task {
                    let ok = await ratingViewModel.submit(
                        requestId: order.id,
                        rating: selectedRating,
                        review: reviewText
                    )
                    if ok {
                        localRating = selectedRating
                        localReview = reviewText.trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                }
            } label: {
                Text(ratingViewModel.isSubmitting ? "Mengirim..." : "Kirim Penilaian")
                    .font(.headline)
                    .foregroundColor(Color(.systemBackground))
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.primary.opacity(selectedRating > 0 ? 0.9 : 0.3))
                    .cornerRadius(16)
            }
            .disabled(selectedRating == 0 || ratingViewModel.isSubmitting)
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
