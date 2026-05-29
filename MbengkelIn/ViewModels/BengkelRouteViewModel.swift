//
//  BengkelRouteViewModel.swift
//  MbengkelIn
//
//  Created by Amadeus Eugine Dirgantara on 29/05/26.
//

import Foundation
import Combine
import CoreLocation
import Supabase

// Bengkel-side: drives the route screen shown after placing an offer. Tracks the
// bengkel's own live GPS (for the map), watches the order status in realtime, and
// — once the order is On Progress — publishes the live location to the customer
// at an adaptive cadence (more frequent when closer).
@MainActor
class BengkelRouteViewModel: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var order: NearbyOrder?
    @Published var bengkelCoordinate: CLLocationCoordinate2D?

    private let locationManager = CLLocationManager()
    private let orderRepository = OrderRepository()
    private let locationRepository = OrderLocationRepository()
    private let authService = AuthService()

    private var serviceRequestId: String?
    private var customerCoordinate: CLLocationCoordinate2D?
    private var lastPublishedAt: Date?
    private var channel: RealtimeChannelV2?

    var status: String { order?.status ?? "To Do" }

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
    }

    deinit {
        if let channel = channel {
            let client = supabase
            Task { await client.removeChannel(channel) }
        }
    }

    func start(order: NearbyOrder) async {
        self.order = order
        self.serviceRequestId = order.id
        self.customerCoordinate = CLLocationCoordinate2D(latitude: order.latitude, longitude: order.longitude)

        let auth = locationManager.authorizationStatus
        if auth == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        } else {
            locationManager.startUpdatingLocation()
        }

        stopChannel()
        let channel = supabase.channel("bengkel-route-\(order.id)")
        self.channel = channel
        let stream = channel.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "service_requests",
            filter: "id=eq.\(order.id)"
        )
        Task { [weak self] in
            guard let self else { return }
            await channel.subscribe()
            for await _ in stream {
                if let updated = try? await self.orderRepository.fetchOrder(id: order.id) {
                    self.order = updated
                }
            }
        }
    }

    func stop() {
        locationManager.stopUpdatingLocation()
        stopChannel()
    }

    private func stopChannel() {
        if let channel = channel {
            Task { await supabase.removeChannel(channel) }
            self.channel = nil
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let auth = manager.authorizationStatus
        if auth == .authorizedWhenInUse || auth == .authorizedAlways {
            manager.startUpdatingLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        self.bengkelCoordinate = location.coordinate

        // Only stream the location to the customer once the order is active.
        guard status == "On Progress", let requestId = serviceRequestId else { return }
        let distance = customerCoordinate.map {
            location.distance(from: CLLocation(latitude: $0.latitude, longitude: $0.longitude))
        } ?? .greatestFiniteMagnitude
        let minInterval = interval(forDistance: distance)
        if let last = lastPublishedAt, Date().timeIntervalSince(last) < minInterval { return }
        lastPublishedAt = Date()
        Task { await publish(coordinate: location.coordinate, requestId: requestId) }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}

    private func interval(forDistance meters: CLLocationDistance) -> TimeInterval {
        switch meters {
        case ..<1000: return 2
        case ..<3000: return 5
        default: return 10
        }
    }

    private func publish(coordinate: CLLocationCoordinate2D, requestId: String) async {
        guard let session = try? await authService.getCurrentSession() else { return }
        let uid = session.user.id.uuidString.lowercased()
        try? await locationRepository.upsertLocation(OrderLocationPayload(
            service_request_id: requestId,
            provider_uid: uid,
            latitude: coordinate.latitude,
            longitude: coordinate.longitude
        ))
    }
}
