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

class OrderViewModel: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var locationAddress: String = ""
    @Published var selectedService: String? = nil
    @Published var estimatedPrice: Int = 0
    @Published var isFetchingLocation: Bool = false
    @Published var isEditingLocation: Bool = false
    @Published var searchResults: [PhotonSearchFeature] = []
    @Published var errorMessage: String?
    @Published var createdServiceRequestId: String? = nil
    @Published var navigateToBidding: Bool = false
    @Published var loadingPhase: LoadingPhase = .idle
    
    @Published var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: -7.2845, longitude: 112.6315),
        span: MKCoordinateSpan(latitudeDelta: 0.003, longitudeDelta: 0.003)
    )
    
    let services = ["Engine", "Tire", "Battery", "Towing"]
    let serviceMinPrices: [String: Int] = [
        "Engine": 100000,
        "Tire": 40000,
        "Battery": 60000,
        "Towing": 150000
    ]
    private let locationManager = CLLocationManager()
    private var cancellables = Set<AnyCancellable>()
    
    private let locationService = LocationService()
    private let orderRepository = OrderRepository()
    
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
        }
        
        fetchAddress(from: location.coordinate)
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        DispatchQueue.main.async { self.isFetchingLocation = false }
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
    
    func selectService(_ service: String) {
        selectedService = service
        calculateEstimate()
    }
    
    private func calculateEstimate() {
        if let service = selectedService {
            estimatedPrice = serviceMinPrices[service] ?? 50000
        } else {
            estimatedPrice = 0
        }
    }
    
    func createOrder() {
        guard let service = selectedService, !locationAddress.isEmpty else { return }
        loadingPhase = .loading(message: "Membuat pesanan...")
        Task { @MainActor in
            self.errorMessage = nil
            do {
                let uid = try await supabase.auth.session.user.id.uuidString.lowercased()
                let payload = ServiceRequestPayload(
                    customer_id: uid,
                    description: service,
                    latitude: self.region.center.latitude,
                    longitude: self.region.center.longitude,
                    price: self.estimatedPrice,
                    is_emergency: false,
                    status: "To Do"
                )
                let created = try await orderRepository.createOrder(payload: payload)
                self.createdServiceRequestId = created.id
                self.loadingPhase = .idle
                self.navigateToBidding = true
            } catch {
                self.errorMessage = error.localizedDescription
                self.loadingPhase = .failed(
                    title: "Gagal membuat pesanan",
                    message: "Periksa koneksi internet kamu dan coba lagi."
                )
            }
        }
    }

    func cancelLoading() {
        loadingPhase = .idle
    }
}
