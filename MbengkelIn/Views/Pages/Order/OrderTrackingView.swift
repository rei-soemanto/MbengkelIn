//
//  OrderTrackingView.swift
//  MbengkelIn
//
//  Created by Bryan Fernando Dinata on 19/05/26.
//

import SwiftUI
import MapKit
import CoreLocation

struct OrderTrackingView: View {
    let bid: Bid
    let customerCoordinate: CLLocationCoordinate2D
    let popToRoot: () -> Void

    @StateObject private var trackingViewModel = OrderTrackingViewModel()
    @StateObject private var chatWatch: ChatWatchViewModel
    @StateObject private var locationPublisher = CustomerLocationPublishViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var region: MKCoordinateRegion
    @State private var showReviewSheet = false
    @State private var didPromptReview = false
    @State private var didFitBoth = false
    @State private var showCancelSheet = false
    @State private var cancelReason = ""
    @State private var didNotifyNear = false
    private let notificationService = NotificationService()

    init(bid: Bid, customerCoordinate: CLLocationCoordinate2D, popToRoot: @escaping () -> Void = {}) {
        self.bid = bid
        self.customerCoordinate = customerCoordinate
        self.popToRoot = popToRoot
        // Default zoom matches the bengkel's route map: start centered on the
        // customer at the shared default span, then fit both once the bengkel's
        // live location arrives.
        _region = State(initialValue: .fitting(customerCoordinate, nil))
        _chatWatch = StateObject(wrappedValue: ChatWatchViewModel(
            serviceRequestId: bid.serviceRequestId,
            counterpartName: bid.bengkel?.name ?? "Bengkel"
        ))
    }

    var body: some View {
        VStack(spacing: 0) {
            TrackingMapView(
                region: $region,
                customerCoordinate: customerCoordinate,
                bengkelCoordinate: liveBengkelCoordinate,
                bengkelName: bid.bengkel?.name ?? "Bengkel"
            )
            TrackingInfoCard(
                bid: bid,
                isLive: trackingViewModel.isLive,
                unreadCount: chatWatch.unreadCount,
                onOpenChat: { chatWatch.markAllRead() },
                canComplete: isBengkelNear,
                onCancel: { showCancelSheet = true }
            )
        }
        .navigationTitle("Bengkel Menuju Lokasi")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    popToRoot()
                } label: {
                    Image(systemName: "chevron.left")
                        .fontWeight(.semibold)
                }
            }
        }
        .task { await trackingViewModel.start(serviceRequestId: bid.serviceRequestId) }
        .task { await chatWatch.start() }
        .onChange(of: trackingViewModel.order?.status) { status in
            if status == "On Progress" {
                locationPublisher.start(serviceRequestId: bid.serviceRequestId)
            }
            if status == "Done" || status == "Cancelled" {
                locationPublisher.stop()
            }
            if status == "Done", !trackingViewModel.alreadyRated, !didPromptReview {
                didPromptReview = true
                showReviewSheet = true
            }
        }
        .onChange(of: trackingViewModel.providerCoordinate?.latitude) { _ in
            fitBothIfNeeded()
            if isBengkelNear, !didNotifyNear {
                didNotifyNear = true
                notificationService.notifyNewOrder(
                    title: "Bengkel sudah dekat",
                    body: "Bengkel berada di sekitar lokasimu. Kamu bisa menyelesaikan pesanan."
                )
            }
        }
        .sheet(isPresented: $showReviewSheet) {
            OrderReviewSheet(requestId: bid.serviceRequestId)
        }
        .sheet(isPresented: $showCancelSheet) {
            NavigationStack {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Pesananmu sudah diterima bengkel. Pembatalan akan ditinjau admin dan dananya ditahan sementara sampai ada keputusan.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    TextField("Alasan pembatalan…", text: $cancelReason, axis: .vertical)
                        .lineLimit(3...6)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    Button {
                        Task {
                            if await trackingViewModel.openDispute(reason: cancelReason) {
                                showCancelSheet = false
                                popToRoot()
                            }
                        }
                    } label: {
                        Text("Kirim Pembatalan")
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red.opacity(cancelReason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.4 : 1))
                            .cornerRadius(12)
                    }
                    .disabled(cancelReason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    Spacer()
                }
                .padding()
                .navigationTitle("Batalkan Pesanan")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Batal") { showCancelSheet = false }
                    }
                }
            }
            .presentationDetents([.medium])
        }
        .onDisappear {
            trackingViewModel.stop()
            chatWatch.stop()
            locationPublisher.stop()
        }
    }

    private func fitBothIfNeeded() {
        guard !didFitBoth, let bengkel = trackingViewModel.providerCoordinate else { return }
        didFitBoth = true
        region = .fitting(customerCoordinate, bengkel)
    }

    private var bengkelDistanceMeters: CLLocationDistance? {
        guard let p = trackingViewModel.providerCoordinate else { return nil }
        return CLLocation(latitude: customerCoordinate.latitude, longitude: customerCoordinate.longitude)
            .distance(from: CLLocation(latitude: p.latitude, longitude: p.longitude))
    }
    private var isBengkelNear: Bool {
        if let d = bengkelDistanceMeters { return d <= 80 }
        return false
    }

    private var liveBengkelCoordinate: CLLocationCoordinate2D? {
        if let live = trackingViewModel.providerCoordinate { return live }
        if let lat = bid.bengkel?.latitude, let lon = bid.bengkel?.longitude {
            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
        return nil
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
