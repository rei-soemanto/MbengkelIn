import Testing
import MapKit
import CoreLocation
@testable import MbengkelIn

@Suite("RegionFit")
struct RegionFitTests {
    @Test func singleValidCoordinate() {
        let region = MKCoordinateRegion.fitting(
            CLLocationCoordinate2D(latitude: -7.28, longitude: 112.63), nil)
        #expect(abs(region.center.latitude - (-7.28)) < 0.0001)
        #expect(abs(region.span.latitudeDelta - 0.02) < 0.0001)
    }

    @Test func invalidFirstFallsBackToOrigin() {
        let region = MKCoordinateRegion.fitting(
            CLLocationCoordinate2D(latitude: .nan, longitude: .nan), nil)
        #expect(abs(region.center.latitude) < 0.0001)
        #expect(abs(region.center.longitude) < 0.0001)
    }

    @Test func closePairUsesMidpoint() {
        let a = CLLocationCoordinate2D(latitude: -7.2845, longitude: 112.6315)
        let b = CLLocationCoordinate2D(latitude: -7.2905, longitude: 112.6360)
        let region = MKCoordinateRegion.fitting(a, b)
        #expect(abs(region.center.latitude - (a.latitude + b.latitude) / 2) < 0.0001)
        #expect(abs(region.center.longitude - (a.longitude + b.longitude) / 2) < 0.0001)
        #expect(region.span.latitudeDelta.isFinite)
        #expect(region.span.latitudeDelta >= 0.005)
        #expect(region.span.latitudeDelta <= 160)
        #expect(region.span.longitudeDelta >= 0.005)
        #expect(region.span.longitudeDelta <= 300)
    }

    @Test func farPairFallsBackToFirst() {
        let surabaya = CLLocationCoordinate2D(latitude: -7.2845, longitude: 112.6315)
        let newYork = CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060)
        let region = MKCoordinateRegion.fitting(surabaya, newYork)
        #expect(abs(region.center.latitude - (-7.2845)) < 0.0001)
        #expect(abs(region.span.latitudeDelta - 0.02) < 0.0001)
    }
}
