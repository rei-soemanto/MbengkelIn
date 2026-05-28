//
//  BengkelViewModel.swift
//  MbengkelIn
//
//  Created by Rei Soemanto on 25/04/26.
//

import SwiftUI
import Combine
import MapKit
import CoreLocation
import Supabase

@MainActor
class BengkelViewModel: NSObject, ObservableObject, CLLocationManagerDelegate, LocationSearchable {
    @Published var myBengkel: Bengkel?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    
    // ── Location / Map state (same pattern as OrderViewModel) ──
    @Published var locationAddress: String = ""
    @Published var isEditingLocation: Bool = false
    @Published var isFetchingLocation: Bool = false
    @Published var searchResults: [PhotonSearchFeature] = []
    @Published var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: -7.2845, longitude: 112.6315),
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )
    
    private let authService = AuthService()
    private let bengkelRepository = BengkelRepository()
    private let locationService = LocationService()
    private let locationManager = CLLocationManager()
    private var cancellables = Set<AnyCancellable>()
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        
        // Debounced search (identical pattern to OrderViewModel)
        $locationAddress
            .debounce(for: .milliseconds(400), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] query in
                guard let self = self else { return }
                if query.isEmpty || !self.isEditingLocation {
                    self.searchResults = []
                } else {
                    self.searchOSM(query: query)
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Location Search (OSM Photon)
    
    private func searchOSM(query: String) {
        Task { @MainActor in
            do {
                let features = try await locationService.searchOSM(query: query, coordinate: region.center)
                self.searchResults = features
            } catch {
                self.searchResults = []
            }
        }
    }
    
    func selectSearchResult(_ result: PhotonSearchFeature) {
        self.isEditingLocation = false
        
        let title = result.properties.name ?? result.properties.street ?? "Unknown Location"
        self.locationAddress = title
        self.searchResults = []
        
        let lon = result.geometry.coordinates[0]
        let lat = result.geometry.coordinates[1]
        let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        
        self.region = MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )
    }
    
    func useCurrentLocation() {
        isFetchingLocation = true
        isEditingLocation = false
        let status = locationManager.authorizationStatus
        
        if status == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        } else if status == .authorizedWhenInUse || status == .authorizedAlways {
            locationManager.requestLocation()
        } else {
            DispatchQueue.main.async { self.isFetchingLocation = false }
        }
    }
    
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            if status == .authorizedWhenInUse || status == .authorizedAlways {
                if isFetchingLocation {
                    manager.requestLocation()
                }
            } else if status != .notDetermined {
                self.isFetchingLocation = false
            }
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.first else { return }
        
        Task { @MainActor in
            self.region = MKCoordinateRegion(
                center: location.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
            self.fetchAddress(from: location.coordinate)
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            self.isFetchingLocation = false
        }
    }
    
    func updateLocationFromMap(coordinate: CLLocationCoordinate2D) {
        if !isEditingLocation {
            fetchAddress(from: coordinate)
        }
    }
    
    private func fetchAddress(from coordinate: CLLocationCoordinate2D) {
        self.isFetchingLocation = true
        Task { @MainActor in
            do {
                if let address = try await locationService.fetchAddress(from: coordinate) {
                    self.locationAddress = address
                }
            } catch {
                // handle error silently
            }
            self.isFetchingLocation = false
        }
    }
    
    // MARK: - Bengkel CRUD
    
    func registerBengkel(name: String, address: String) async -> Bool {
        isLoading = true
        errorMessage = nil
        successMessage = nil
        
        guard let session = try? await authService.getCurrentSession() else {
            self.errorMessage = "You must be logged in to register a Bengkel."
            isLoading = false
            return false
        }
        let uid = session.user.id.uuidString.lowercased()
        
        // Coordinates come from region.center (set by map/search picker)
        let lat = region.center.latitude
        let lon = region.center.longitude
        
        let newBengkel = Bengkel(
            id: nil,
            providerUid: uid,
            name: name,
            address: address,
            latitude: lat,
            longitude: lon,
            status: "Pending",
            offeredServices: [],
            averageRating: 0.0,
            totalReviews: 0,
            createdAt: nil
        )
        
        do {
            try await bengkelRepository.insertBengkel(newBengkel)
            self.successMessage = "Bengkel submitted for review! You will be notified once approved."
            isLoading = false
            return true
        } catch {
            self.errorMessage = error.localizedDescription
            isLoading = false
            return false
        }
    }
    
    func fetchMyBengkel(uid: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let fetchedBengkel = try await bengkelRepository.fetchBengkel(providerUid: uid)
            self.myBengkel = fetchedBengkel
        } catch {
            self.errorMessage = "Failed to load Bengkel: \(error.localizedDescription)"
        }
        isLoading = false
    }

    func updateBengkel(bengkelId: String, name: String, address: String) async -> Bool {
        isLoading = true
        errorMessage = nil
        
        let payload = BengkelUpdatePayload(
            name: name,
            address: address,
            latitude: region.center.latitude,
            longitude: region.center.longitude
        )
        
        do {
            try await bengkelRepository.updateBengkel(bengkelId: bengkelId, payload: payload)
            isLoading = false
            return true
        } catch {
            self.errorMessage = error.localizedDescription
            isLoading = false
            return false
        }
    }
    
    func deleteBengkel(bengkelId: String, password: String, email: String) async -> Bool {
        isLoading = true
        errorMessage = nil
        do {
            _ = try await authService.signIn(email: email, password: password)
            
            try await bengkelRepository.deleteBengkel(bengkelId: bengkelId)
            
            self.myBengkel = nil
            isLoading = false
            return true
        } catch {
            self.errorMessage = error.localizedDescription
            isLoading = false
            return false
        }
    }

    // MARK: - Bengkel Services CRUD

    func addService(bengkelId: String, serviceType: ServiceType, isActive: Bool) async -> Bool {
        isLoading = true
        errorMessage = nil
        
        do {
            guard var currentBengkel = self.myBengkel else {
                self.errorMessage = "Bengkel data not found."
                isLoading = false
                return false
            }
            
            let newService = BengkelService(
                serviceType: serviceType,
                isActive: isActive
            )
            
            currentBengkel.offeredServices.append(newService)
            
            let payload = BengkelServicesUpdatePayload(offered_services: currentBengkel.offeredServices)
            try await bengkelRepository.updateServices(bengkelId: bengkelId, payload: payload)
            
            self.myBengkel = currentBengkel
            
            isLoading = false
            return true
        } catch {
            self.errorMessage = error.localizedDescription
            isLoading = false
            return false
        }
    }
    
    func updateService(bengkelId: String, serviceId: String, serviceType: ServiceType, isActive: Bool) async -> Bool {
        isLoading = true
        errorMessage = nil
        
        do {
            guard var currentBengkel = self.myBengkel else { return false }
            
            if let index = currentBengkel.offeredServices.firstIndex(where: { $0.id == serviceId }) {
                currentBengkel.offeredServices[index].serviceType = serviceType
                currentBengkel.offeredServices[index].isActive = isActive
                
                let payload = BengkelServicesUpdatePayload(offered_services: currentBengkel.offeredServices)
                try await bengkelRepository.updateServices(bengkelId: bengkelId, payload: payload)
                
                self.myBengkel = currentBengkel
            }
            
            isLoading = false
            return true
        } catch {
            self.errorMessage = error.localizedDescription
            isLoading = false
            return false
        }
    }

    func deleteService(bengkelId: String, serviceId: String) async -> Bool {
        isLoading = true
        errorMessage = nil
        
        do {
            guard var currentBengkel = self.myBengkel else { return false }
            
            currentBengkel.offeredServices.removeAll { $0.id == serviceId }
            
            let payload = BengkelServicesUpdatePayload(offered_services: currentBengkel.offeredServices)
            try await bengkelRepository.updateServices(bengkelId: bengkelId, payload: payload)
            
            self.myBengkel = currentBengkel
            
            isLoading = false
            return true
        } catch {
            self.errorMessage = error.localizedDescription
            isLoading = false
            return false
        }
    }
}
