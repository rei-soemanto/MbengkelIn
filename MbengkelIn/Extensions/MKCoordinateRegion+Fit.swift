//
//  MKCoordinateRegion+Fit.swift
//  MbengkelIn
//
//  Created by Bryan Fernando Dinata on 29/05/26.
//

import MapKit
import CoreLocation

extension MKCoordinateRegion {
    static func fitting(
        _ first: CLLocationCoordinate2D,
        _ second: CLLocationCoordinate2D?,
        defaultSpan: CLLocationDegrees = 0.02,
        maxFitMeters: CLLocationDistance = 60_000
    ) -> MKCoordinateRegion {
        let firstValid = CLLocationCoordinate2DIsValid(first)
            && first.latitude.isFinite && first.longitude.isFinite

        guard firstValid else {
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
                span: MKCoordinateSpan(latitudeDelta: defaultSpan, longitudeDelta: defaultSpan)
            )
        }

        let firstCentered = MKCoordinateRegion(
            center: first,
            span: MKCoordinateSpan(latitudeDelta: defaultSpan, longitudeDelta: defaultSpan)
        )

        guard let second = second,
              CLLocationCoordinate2DIsValid(second),
              second.latitude.isFinite, second.longitude.isFinite else {
            return firstCentered
        }

        let separation = CLLocation(latitude: first.latitude, longitude: first.longitude)
            .distance(from: CLLocation(latitude: second.latitude, longitude: second.longitude))
        guard separation <= maxFitMeters else {
            return firstCentered
        }

        let midLat = (first.latitude + second.latitude) / 2
        let midLon = (first.longitude + second.longitude) / 2
        let latSpan = min(max(abs(first.latitude - second.latitude) * 2.5 + 0.01, 0.005), 160)
        let lonSpan = min(max(abs(first.longitude - second.longitude) * 2.5 + 0.01, 0.005), 300)

        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: midLat, longitude: midLon),
            span: MKCoordinateSpan(latitudeDelta: latSpan, longitudeDelta: lonSpan)
        )
    }
}
