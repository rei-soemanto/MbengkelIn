//
//  OrderViewModel.swift
//  BengkelIn
//
//  Created by Bryan Fernando Dinata on 19/05/26.
//

import Foundation
import Combine
import MapKit
import CoreLocation

class OrderViewModel: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var locationAddress: String = ""
    @Published var selectedService: String? = nil
    @Published var estimatedPrice: Int = 0
    @Published var isFetchingLocation: Bool = false
    @Published var isEditingLocation: Bool = false
    @Published var searchResults: [PhotonSearchFeature] = []
    
    @Published var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: -7.2845, longitude: 112.6315),
        span: MKCoordinateSpan(latitudeDelta: 0.003, longitudeDelta: 0.003)
    )
    
    let services = ["Engine", "Tire", "Battery", "Towing"]
    private let locationManager = CLLocationManager()
    private var cancellables = Set<AnyCancellable>()
    
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
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://photon.komoot.io/api/?q=\(encodedQuery)&limit=5&lat=\(region.center.latitude)&lon=\(region.center.longitude)") else { return }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let data = data, error == nil else { return }
            do {
                let result = try JSONDecoder().decode(PhotonSearchResponse.self, from: data)
                DispatchQueue.main.async {
                    self?.searchResults = result.features
                }
            } catch {
                DispatchQueue.main.async {
                    self?.searchResults = []
                }
            }
        }.resume()
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
        let urlString = "https://photon.komoot.io/reverse?lon=\(coordinate.longitude)&lat=\(coordinate.latitude)"
        guard let url = URL(string: urlString) else {
            DispatchQueue.main.async { self.isFetchingLocation = false }
            return
        }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let data = data, error == nil else {
                DispatchQueue.main.async { self?.isFetchingLocation = false }
                return
            }
            
            do {
                let photonResponse = try JSONDecoder().decode(PhotonSearchResponse.self, from: data)
                if let properties = photonResponse.features.first?.properties {
                    let addressParts = [properties.name, properties.street, properties.city, properties.state]
                        .compactMap { $0 }
                        .filter { !$0.isEmpty }
                    
                    DispatchQueue.main.async {
                        self?.locationAddress = addressParts.joined(separator: ", ")
                        self?.isFetchingLocation = false
                    }
                } else {
                    DispatchQueue.main.async { self?.isFetchingLocation = false }
                }
            } catch {
                DispatchQueue.main.async { self?.isFetchingLocation = false }
            }
        }.resume()
    }
    
    func selectService(_ service: String) {
        selectedService = service
        calculateEstimate()
    }
    
    private func calculateEstimate() {
        estimatedPrice = Int.random(in: 50000...200000)
    }
    
    func createOrder() {
        guard selectedService != nil, !locationAddress.isEmpty else { return }
    }
}
