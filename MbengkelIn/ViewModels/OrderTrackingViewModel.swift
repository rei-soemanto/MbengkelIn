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

// Customer-side: subscribes to the assigned bengkel's live location for an
// in-progress order via Supabase Realtime and exposes the latest coordinate.
@MainActor
class OrderTrackingViewModel: ObservableObject {
    @Published var providerCoordinate: CLLocationCoordinate2D?
    @Published var lastUpdated: String?

    private let repository = OrderLocationRepository()
    private var channel: RealtimeChannelV2?
    private var serviceRequestId: String?

    deinit {
        if let channel = channel {
            let client = supabase
            Task { await client.removeChannel(channel) }
        }
    }

    func start(serviceRequestId: String) async {
        self.serviceRequestId = serviceRequestId

        // Seed with the latest known location, if any.
        if let location = try? await repository.fetchLocation(serviceRequestId: serviceRequestId) {
            apply(location)
        }

        stop()
        let channel = supabase.channel("order-location-\(serviceRequestId)")
        self.channel = channel

        let stream = channel.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "order_locations",
            filter: "service_request_id=eq.\(serviceRequestId)"
        )

        Task { [weak self] in
            guard let self else { return }
            await channel.subscribe()
            for await _ in stream {
                if let location = try? await self.repository.fetchLocation(serviceRequestId: serviceRequestId) {
                    self.apply(location)
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
