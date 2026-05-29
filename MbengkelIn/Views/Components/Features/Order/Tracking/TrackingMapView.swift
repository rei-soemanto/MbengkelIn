//
//  TrackingMapView.swift
//  MbengkelIn
//
//  Created by Bryan Fernando Dinata on 19/05/26.
//

import SwiftUI
import MapKit
import CoreLocation

struct TrackingPin: Identifiable {
    let id: String
    let coordinate: CLLocationCoordinate2D
    let label: String
    let icon: String
    let tint: Color
}

struct TrackingMapView: View {
    @Binding var region: MKCoordinateRegion
    let customerCoordinate: CLLocationCoordinate2D
    let bengkelCoordinate: CLLocationCoordinate2D?
    let bengkelName: String

    var body: some View {
        Map(coordinateRegion: $region, annotationItems: pins) { item in
            MapAnnotation(coordinate: item.coordinate) {
                VStack(spacing: 2) {
                    Image(systemName: item.icon)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)
                        .padding(10)
                        .background(item.tint)
                        .clipShape(Circle())
                    Text(item.label)
                        .font(.caption2.bold())
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color(.systemBackground))
                        .cornerRadius(6)
                }
            }
        }
    }

    private var pins: [TrackingPin] {
        var list = [TrackingPin(id: "you", coordinate: customerCoordinate,
                                label: "Anda", icon: "person.fill", tint: .blue)]
        if let coordinate = bengkelCoordinate {
            list.append(TrackingPin(
                id: "bengkel",
                coordinate: coordinate,
                label: bengkelName,
                icon: "car.fill",
                tint: .primary))
        }
        return list
    }
}
