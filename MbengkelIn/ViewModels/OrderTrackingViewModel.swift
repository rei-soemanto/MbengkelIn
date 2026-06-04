//
//  OrderTrackingViewModel.swift
//  MbengkelIn
//
//  Created by Amadeus Eugine Dirgantara on 29/05/26.
//

import Foundation
import Combine
import CoreLocation
import Supabase

// Customer-side: for an in-progress order, subscribes via Supabase Realtime to
//  1) the assigned bengkel's live location (order_locations), and
//  2) the order row itself (service_requests) — so the moment it settles to
//     "Done" we can prompt the customer for a review.
@MainActor
class OrderTrackingViewModel: ObservableObject, Sendable {
    @Published var providerCoordinate: CLLocationCoordinate2D?
    @Published var lastUpdated: String?
    @Published var order: NearbyOrder?
    @Published var isLive = false

    private let locationRepository = OrderLocationRepository()
    private let orderRepository = OrderRepository()
    private let notificationService = NotificationService()
    private var iInitiatedCancel = false
    private var channel: RealtimeChannelV2?
    private var serviceRequestId: String?
    private var realtimeReaderTasks: [Task<Void, Never>] = []

    var status: String { order?.status ?? "On Progress" }
    var alreadyRated: Bool { (order?.rating ?? 0) > 0 }

    deinit {
        realtimeReaderTasks.forEach { $0.cancel() }
        realtimeReaderTasks.removeAll()
        if let channel = channel {
            Task { await supabase.removeChannel(channel) }
        }
    }

    func start(serviceRequestId: String) async {
        self.serviceRequestId = serviceRequestId
        // Notification authorization is requested when tracking begins.

        // Seed with whatever is already known.
        if let location = try? await locationRepository.fetchLocation(serviceRequestId: serviceRequestId) {
            apply(location)
        }
        self.order = try? await orderRepository.fetchOrder(id: serviceRequestId)

        stop()
        let channel = supabase.channel("order-tracking-\(serviceRequestId)")
        self.channel = channel

        let locationStream = channel.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "order_locations",
            filter: .eq("service_request_id", value: serviceRequestId)
        )
        let orderStream = channel.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "service_requests",
            filter: .eq("id", value: serviceRequestId)
        )

        realtimeReaderTasks.append(Task { [weak self] in
            guard let self else { return }
            try? await channel.subscribeWithError()

            Task { [weak self] in
                guard let self else { return }
                for await status in channel.statusChange {
                    if status != .subscribed { self.isLive = false }
                }
            }
            Task { [weak self] in
                for await _ in locationStream {
                    guard let self else { return }
                    if let location = try? await self.locationRepository.fetchLocation(serviceRequestId: serviceRequestId) {
                        self.apply(location)
                        self.isLive = true
                    }
                }
            }
            Task { [weak self] in
                for await _ in orderStream {
                    guard let self else { return }
                    if let updated = try? await self.orderRepository.fetchOrder(id: serviceRequestId) {
                        let previous = self.order
                        self.order = updated
                        self.notifyOnCancellation(previous: previous, updated: updated)
                    }
                }
            }
        })
    }

    func stop() {
        isLive = false
        realtimeReaderTasks.forEach { $0.cancel() }
        realtimeReaderTasks.removeAll()
        if let channel = channel {
            Task { await supabase.removeChannel(channel) }
            self.channel = nil
        }
    }

    func openDispute(reason: String) async -> Bool {
        guard let id = serviceRequestId else { return false }
        do {
            iInitiatedCancel = true
            _ = try await orderRepository.openDispute(requestId: id, reason: reason)
            return true
        } catch {
            iInitiatedCancel = false
            return false
        }
    }

    private func notifyOnCancellation(previous: NearbyOrder?, updated: NearbyOrder) {
        guard previous?.status != "Cancelled", updated.status == "Cancelled" else { return }
        if iInitiatedCancel { iInitiatedCancel = false; return }
        notificationService.notifyNewOrder(
            title: "Pesanan dibatalkan",
            body: "Bengkel membatalkan pesanan ini."
        )
    }

    func notifyBengkelNear() {
        notificationService.notifyNewOrder(
            title: "Bengkel sudah dekat",
            body: "Bengkel berada di sekitar lokasimu. Kamu bisa menyelesaikan pesanan."
        )
    }

    private func apply(_ location: OrderLocation) {
        self.providerCoordinate = CLLocationCoordinate2D(
            latitude: location.latitude,
            longitude: location.longitude
        )
        self.lastUpdated = location.updatedAt
    }
}
