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
    @Published var todaysEarnings: Double = 0

    // Location / Map state
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
    private let orderRepository = OrderRepository()
    private let locationService = LocationService()
    private let locationManager = CLLocationManager()
    private var cancellables = Set<AnyCancellable>()
    private var realtimeChannel: RealtimeChannelV2?
    private var realtimeReaderTasks: [Task<Void, Never>] = []

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        
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
            }
            self.isFetchingLocation = false
        }
    }
    
    func registerBengkel(name: String, address: String) async -> Bool {
        isLoading = true
        errorMessage = nil
        successMessage = nil
        
        guard let session = try? await authService.getCurrentSession() else {
            self.errorMessage = "Anda harus masuk untuk mendaftarkan Bengkel."
            isLoading = false
            return false
        }
        let uid = session.user.id.uuidString.lowercased()
        
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
            self.successMessage = "Bengkel diajukan untuk ditinjau! Anda akan diberi tahu setelah disetujui."
            isLoading = false
            return true
        } catch {
            self.errorMessage = error.localizedDescription
            isLoading = false
            return false
        }
    }
    
    deinit {
        realtimeReaderTasks.forEach { $0.cancel() }
        realtimeReaderTasks.removeAll()
        if let channel = realtimeChannel {
            let client = supabase
            Task {
                await client.removeChannel(channel)
            }
        }
    }

    // Loads the bengkel once, then keeps its status (e.g. Pending -> Verified)
    // live via a realtime subscription. Avoids needing a relog.
    func startWatching(uid: String) async {
        await fetchMyBengkel(uid: uid)
        await loadTodaysEarnings()
        startRealtimeSubscription(uid: uid)
    }

    func loadTodaysEarnings() async {
        guard let bengkelId = myBengkel?.id else { return }
        do {
            self.todaysEarnings = try await orderRepository.fetchTodaysEarnings(bengkelId: bengkelId)
        } catch {
        }
    }

    private func startRealtimeSubscription(uid: String) {
        stopWatching()

        let channel = supabase.channel("bengkel-status-\(uid)")
        self.realtimeChannel = channel

        let stream = channel.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "bengkels",
            filter: "provider_uid=eq.\(uid)"
        )

        realtimeReaderTasks.append(Task { [weak self] in
            guard let self = self else { return }
            await channel.subscribe()
            for await _ in stream {
                await self.refreshBengkelQuietly(uid: uid)
            }
        })

    }

    func stopWatching() {
        realtimeReaderTasks.forEach { $0.cancel() }
        realtimeReaderTasks.removeAll()
        if let channel = realtimeChannel {
            Task {
                await supabase.removeChannel(channel)
            }
            realtimeChannel = nil
        }
    }

    // Background refresh that does NOT toggle isLoading (prevents spinner flicker).
    func refreshBengkelQuietly(uid: String) async {
        do {
            let fetched = try await bengkelRepository.fetchBengkel(providerUid: uid)
            self.myBengkel = fetched
        } catch {
            // ignore transient errors during background refresh
        }
    }

    func fetchMyBengkel(uid: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let fetchedBengkel = try await bengkelRepository.fetchBengkel(providerUid: uid)
            self.myBengkel = fetchedBengkel
        } catch {
            self.errorMessage = "Gagal memuat Bengkel: \(error.localizedDescription)"
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

    func addService(bengkelId: String, serviceType: ServiceType, isActive: Bool) async -> Bool {
        isLoading = true
        errorMessage = nil
        
        do {
            guard var currentBengkel = self.myBengkel else {
                self.errorMessage = "Data bengkel tidak ditemukan."
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
