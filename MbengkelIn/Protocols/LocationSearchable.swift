//
//  LocationSearchable.swift
//  MbengkelIn
//
//  Created by Rei Soemanto on 27/05/26.
//

import MapKit

@MainActor
protocol LocationSearchable: ObservableObject {
    var locationAddress: String { get set }
    var isEditingLocation: Bool { get set }
    var isFetchingLocation: Bool { get }
    var searchResults: [PhotonSearchFeature] { get set }
    var region: MKCoordinateRegion { get set }

    func useCurrentLocation()
    func selectSearchResult(_ result: PhotonSearchFeature)
    func updateLocationFromMap(coordinate: CLLocationCoordinate2D)
}
