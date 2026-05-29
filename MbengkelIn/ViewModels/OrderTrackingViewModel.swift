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
class OrderTrackingViewModel: ObservableObject {
    @Published var providerCoordinate: CLLocationCoordinate2D?
    @Published var lastUpdated: String?
    @Published var order: NearbyOrder?

    private let locationRepository = OrderLocationRepository()
    private let orderRepository = OrderRepository()
    private var channel: RealtimeChannelV2?
    private var serviceRequestId: String?

    var status: String { order?.status ?? "On Progress" }
    var alreadyRated: Bool { (order?.rating ?? 0) > 0 }

    deinit {
        if let channel = channel {
            let client = supabase
            Task { await client.removeChannel(channel) }
        }
    }

    func start(serviceRequestId: String) async {
        self.serviceRequestId = serviceRequestId

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
            filter: "service_request_id=eq.\(serviceRequestId)"
        )
        let orderStream = channel.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "service_requests",
            filter: "id=eq.\(serviceRequestId)"
        )

        Task { [weak self] in
            guard let self else { return }
            await channel.subscribe()

            Task { [weak self] in
                for await _ in locationStream {
                    guard let self else { return }
                    if let location = try? await self.locationRepository.fetchLocation(serviceRequestId: serviceRequestId) {
                        self.apply(location)
                    }
                }
            }
            Task { [weak self] in
                for await _ in orderStream {
                    guard let self else { return }
                    if let updated = try? await self.orderRepository.fetchOrder(id: serviceRequestId) {
                        self.order = updated
                    }
                }
            }
        }
    }

    func stop() {
        if let channel = channel {
            Task { await supabase.removeChannel(channel) }
            self.channel = nil
        }
    }

    private func apply(_ location: OrderLocation) {
        self.providerCoordinate = CLLocationCoordinate2D(
            latitude: location.latitude,
            longitude: location.longitude
        )
        self.lastUpdated = location.updatedAt
    }
}
