//
//  OrderViewModel.swift
//  MbengkelIn
//
//  Created by Bryan Fernando Dinata on 19/05/26.
//

import Foundation
import Combine
import MapKit
import CoreLocation
import Supabase

class OrderViewModel: NSObject, ObservableObject, CLLocationManagerDelegate, LocationSearchable {
    @Published var locationAddress: String = ""
    @Published var selectedService: String? = nil
    @Published var estimatedPrice: Int = 0
    @Published var isFetchingLocation: Bool = false
    @Published var isEditingLocation: Bool = false
    @Published var searchResults: [PhotonSearchFeature] = []
    @Published var errorMessage: String?
    @Published var tireCount: Int = 1
    @Published var photosData: [Data?] = [nil]
    @Published var pendingServiceType: ServiceType? = nil
    @Published var pendingTireCount: Int = 1
    @Published var pendingPhotoUrls: [String] = []
    @Published var navigateToBidding: Bool = false
    @Published var loadingPhase: LoadingPhase = .idle

    // True only once a *real* location has been resolved for this order — via
    // GPS, a map drag, or a search selection. Guards against silently creating
    // an order at the hard-coded default coordinate (or a coordinate left over
    // from a previous order), which is the root cause of far-away matches.
    @Published var hasResolvedLocation: Bool = false

    var requiresTireCount: Bool {
        selectedService == "Ban Gembos" || selectedService == "Ban Pecah"
    }

    static let defaultCenter = CLLocationCoordinate2D(latitude: -7.2845, longitude: 112.6315)

    @Published var region = MKCoordinateRegion(
        center: OrderViewModel.defaultCenter,
        span: MKCoordinateSpan(latitudeDelta: 0.003, longitudeDelta: 0.003)
    )
    
    let services = ["Ban Gembos", "Ban Pecah", "Aki Kering"]
    let serviceMinPrices: [String: Int] = [
        "Ban Gembos": 25000,
        "Ban Pecah": 40000,
        "Aki Kering": 60000,
    ]
    private let locationManager = CLLocationManager()
    private var cancellables = Set<AnyCancellable>()
    
    private let locationService = LocationService()
    private let orderRepository = OrderRepository()
    private let storageService = StorageService()

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
            span: MKCoordinateSpan(latitudeDelta: 0.003, longitudeDelta: 0.003)
        )
        self.hasResolvedLocation = true
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
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            if isFetchingLocation {
                manager.requestLocation()
            }
        } else if status != .notDetermined {
            DispatchQueue.main.async { self.isFetchingLocation = false }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.first else { return }
        
        DispatchQueue.main.async {
            self.region = MKCoordinateRegion(
                center: location.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.003, longitudeDelta: 0.003)
            )
            self.hasResolvedLocation = true
        }
        
        fetchAddress(from: location.coordinate)
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        DispatchQueue.main.async { self.isFetchingLocation = false }
    }
    
    func updateLocationFromMap(coordinate: CLLocationCoordinate2D) {
        if !isEditingLocation {
            // A user-driven map pan is a genuine location choice.
            hasResolvedLocation = true
            fetchAddress(from: coordinate)
        }
    }

    // Reset all per-order state so each new order starts from a clean slate and
    // must re-resolve its location. Call when the order form appears.
    func prepareForNewOrder() {
        selectedService = nil
        estimatedPrice = 0
        tireCount = 1
        photosData = [nil]
        pendingServiceType = nil
        pendingTireCount = 1
        pendingPhotoUrls = []
        navigateToBidding = false
        hasResolvedLocation = false
        locationAddress = ""
        searchResults = []
        isEditingLocation = false
        region = MKCoordinateRegion(
            center: OrderViewModel.defaultCenter,
            span: MKCoordinateSpan(latitudeDelta: 0.003, longitudeDelta: 0.003)
        )
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
    
    func selectService(_ service: String) {
        selectedService = service
        tireCount = 1
        photosData = [nil]
        calculateEstimate()
    }

    func setTireCount(_ count: Int) {
        let clamped = min(4, max(1, count))
        tireCount = clamped
        if photosData.count < clamped {
            photosData.append(contentsOf: Array(repeating: nil, count: clamped - photosData.count))
        } else if photosData.count > clamped {
            photosData = Array(photosData.prefix(clamped))
        }
        calculateEstimate()
    }

    private func calculateEstimate() {
        guard let service = selectedService else {
            estimatedPrice = 0
            return
        }
        let base = serviceMinPrices[service] ?? 50000
        estimatedPrice = requiresTireCount ? base * tireCount : base
    }

    func createOrder() {
        guard let service = selectedService, !locationAddress.isEmpty else { return }
        guard hasResolvedLocation else {
            self.errorMessage = "Tentukan lokasi kamu dulu (gunakan lokasi saat ini, geser peta, atau cari alamat)."
            return
        }
        guard let serviceType = ServiceType(rawValue: service) else {
            self.errorMessage = "Layanan tidak dikenali."
            return
        }
        if requiresTireCount {
            let provided = photosData.compactMap { $0 }
            guard provided.count == tireCount else {
                self.errorMessage = "Mohon sertakan \(tireCount) foto kondisi ban (satu per ban)."
                return
            }
        }
        self.errorMessage = nil
        loadingPhase = .loading(message: "Mengunggah foto...")
        Task { @MainActor in
            do {
                var uploadedUrls: [String] = []
                let datas = photosData.compactMap { $0 }
                if !datas.isEmpty {
                    let uid = try await supabase.auth.session.user.id.uuidString.lowercased()
                    for data in datas {
                        let url = try await storageService.uploadOrderPhoto(uid: uid, data: data)
                        uploadedUrls.append(url)
                    }
                }
                self.pendingServiceType = serviceType
                self.pendingTireCount = requiresTireCount ? tireCount : 1
                self.pendingPhotoUrls = uploadedUrls
                self.loadingPhase = .idle
                self.navigateToBidding = true
            } catch {
                self.errorMessage = error.localizedDescription
                self.loadingPhase = .failed(
                    title: "Gagal mengunggah foto",
                    message: "Periksa koneksi internet kamu dan coba lagi."
                )
            }
        }
    }

    func cancelLoading() {
        loadingPhase = .idle
    }
}
