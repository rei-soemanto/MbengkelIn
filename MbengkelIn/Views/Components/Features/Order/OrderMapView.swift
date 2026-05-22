//
//  OSMMapView.swift
//  MbengkelIn
//
//  Created by Bryan Fernando Dinata on 19/05/26.
//
import SwiftUI
import MapKit

struct OrderMapView: UIViewRepresentable {
    @Binding var region: MKCoordinateRegion
    var onRegionChange: (CLLocationCoordinate2D) -> Void
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        mapView.setRegion(region, animated: false)
        return mapView
    }
    
    func updateUIView(_ uiView: MKMapView, context: Context) {
        let mapCenter = CLLocation(latitude: uiView.region.center.latitude, longitude: uiView.region.center.longitude)
        let stateCenter = CLLocation(latitude: region.center.latitude, longitude: region.center.longitude)
        
        if mapCenter.distance(from: stateCenter) > 50 {
            uiView.setRegion(region, animated: true)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: OrderMapView
        
        init(_ parent: OrderMapView) {
            self.parent = parent
        }
        
        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            DispatchQueue.main.async {
                self.parent.region = mapView.region
                self.parent.onRegionChange(mapView.centerCoordinate)
            }
        }
    }
}
