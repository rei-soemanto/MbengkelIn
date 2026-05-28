//
//  OSMMapView.swift
//  MbengkelIn
//
//  Created by Bryan Fernando Dinata on 19/05/26.
//
import SwiftUI
import MapKit

final class OSMTileOverlay: MKTileOverlay {
    override func loadTile(at path: MKTileOverlayPath, result: @escaping (Data?, Error?) -> Void) {
        let url = self.url(forTilePath: path)
        var request = URLRequest(url: url)
        request.setValue("MbengkelIn/1.0 (university project)", forHTTPHeaderField: "User-Agent")

        let task = URLSession.shared.dataTask(with: request) { data, _, error in
            result(data, error)
        }
        task.resume()
    }
}

struct OrderMapView: UIViewRepresentable {
    @Binding var region: MKCoordinateRegion
    var isEditing: Bool
    var onRegionChange: (CLLocationCoordinate2D) -> Void

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.isZoomEnabled = true
        mapView.isScrollEnabled = true
        mapView.isRotateEnabled = true
        mapView.isPitchEnabled = true
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        mapView.setRegion(region, animated: false)

        let overlay = OSMTileOverlay(urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png")
        overlay.canReplaceMapContent = true
        mapView.addOverlay(overlay, level: .aboveLabels)

        return mapView
    }

    func updateUIView(_ uiView: MKMapView, context: Context) {
        context.coordinator.parent = self

        guard !context.coordinator.isProgrammaticChange else { return }

        let mapCenter = CLLocation(latitude: uiView.region.center.latitude, longitude: uiView.region.center.longitude)
        let stateCenter = CLLocation(latitude: region.center.latitude, longitude: region.center.longitude)

        if mapCenter.distance(from: stateCenter) > 100 {
            context.coordinator.isProgrammaticChange = true
            uiView.setRegion(region, animated: true)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: OrderMapView
        var isProgrammaticChange = false
        private var geocodeWorkItem: DispatchWorkItem?
        private var lastGeocodedCoordinate: CLLocationCoordinate2D?

        init(_ parent: OrderMapView) {
            self.parent = parent
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let tileOverlay = overlay as? MKTileOverlay {
                return MKTileOverlayRenderer(tileOverlay: tileOverlay)
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            if isProgrammaticChange {
                isProgrammaticChange = false
                return
            }

            if parent.isEditing {
                return
            }

            let newRegion = mapView.region
            let coordinate = mapView.centerCoordinate

            let oldCenter = CLLocation(latitude: parent.region.center.latitude, longitude: parent.region.center.longitude)
            let newCenter = CLLocation(latitude: newRegion.center.latitude, longitude: newRegion.center.longitude)
            let spanChanged = abs(parent.region.span.latitudeDelta - newRegion.span.latitudeDelta) > 0.0001
                || abs(parent.region.span.longitudeDelta - newRegion.span.longitudeDelta) > 0.0001

            if oldCenter.distance(from: newCenter) > 1 || spanChanged {
                DispatchQueue.main.async {
                    self.parent.region = newRegion
                }
            }

            if let last = lastGeocodedCoordinate {
                let lastLoc = CLLocation(latitude: last.latitude, longitude: last.longitude)
                let newLoc = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
                if lastLoc.distance(from: newLoc) < 30 { return }
            }

            geocodeWorkItem?.cancel()
            let workItem = DispatchWorkItem { [weak self] in
                self?.lastGeocodedCoordinate = coordinate
                self?.parent.onRegionChange(coordinate)
            }
            geocodeWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8, execute: workItem)
        }
    }
}
