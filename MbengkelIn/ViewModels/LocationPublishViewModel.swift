//
//  LocationPublishViewModel.swift
//  MbengkelIn
//
//  Created by Amadeus Eugine Dirgantara on 29/05/26.
//

import Foundation
import Combine
import CoreLocation
import Supabase

// Provider-side: publishes the bengkel's live GPS location for an in-progress
// order. Sampling cadence adapts to how close the bengkel is to the customer
// (more frequent when near), so the customer sees smoother tracking near
// arrival without wasting writes when far away.
@MainActor
class LocationPublishViewModel: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var isPublishing = false
    @Published var errorMessage: String?

    private let locationManager = CLLocationManager()
    private let repository = OrderLocationRepository()
    private let authService = AuthService()

    private var serviceRequestId: String?
    private var customerCoordinate: CLLocationCoordinate2D?
    private var lastPublishedAt: Date?

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        // Background location updates require the `location` UIBackgroundMode in
        // the bundle's Info.plist; enabling them without it throws at runtime.
        // Guard so the app never crashes if that capability isn't built in — the
        // mechanic still streams live while the app is in the foreground.
        if let backgroundModes = Bundle.main.object(forInfoDictionaryKey: "UIBackgroundModes") as? [String],
           backgroundModes.contains("location") {
            locationManager.allowsBackgroundLocationUpdates = true
            locationManager.pausesLocationUpdatesAutomatically = false
        }
    }

    func start(serviceRequestId: String, customerCoordinate: CLLocationCoordinate2D) {
        self.serviceRequestId = serviceRequestId
        self.customerCoordinate = customerCoordinate
        self.lastPublishedAt = nil
        isPublishing = true

        let status = locationManager.authorizationStatus
        if status == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        } else if status == .authorizedWhenInUse || status == .authorizedAlways {
            locationManager.startUpdatingLocation()
        }
    }

    func stop() {
        locationManager.stopUpdatingLocation()
        isPublishing = false
        serviceRequestId = nil
        customerCoordinate = nil
        lastPublishedAt = nil
    }

    // Adaptive interval based on distance to the customer (meters).
    private func interval(forDistance meters: CLLocationDistance) -> TimeInterval {
        switch meters {
        case ..<1000: return 2      // close: refresh every 2s
        case ..<3000: return 5      // mid-range
        default: return 10          // far: every 10s
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        if isPublishing, status == .authorizedWhenInUse || status == .authorizedAlways {
            manager.startUpdatingLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard isPublishing, let location = locations.last, let requestId = serviceRequestId else { return }

        let distance: CLLocationDistance
        if let customer = customerCoordinate {
            distance = location.distance(from: CLLocation(latitude: customer.latitude, longitude: customer.longitude))
        } else {
            distance = .greatestFiniteMagnitude
        }

        // Throttle writes to the adaptive interval.
        let minInterval = interval(forDistance: distance)
        if let last = lastPublishedAt, Date().timeIntervalSince(last) < minInterval {
            return
        }
        lastPublishedAt = Date()

        Task { await publish(coordinate: location.coordinate, requestId: requestId) }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Transient GPS errors are ignored; updates resume on the next fix.
    }

    private func publish(coordinate: CLLocationCoordinate2D, requestId: String) async {
        guard let session = try? await authService.getCurrentSession() else { return }
        let uid = session.user.id.uuidString.lowercased()
        do {
            try await repository.upsertLocation(OrderLocationPayload(
                service_request_id: requestId,
                provider_uid: uid,
                latitude: coordinate.latitude,
                longitude: coordinate.longitude
            ))
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }
}
