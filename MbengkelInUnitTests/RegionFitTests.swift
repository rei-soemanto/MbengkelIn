//
//  RegionFitTests.swift
//  MbengkelInUnitTests
//

import XCTest
import MapKit
import CoreLocation
@testable import MbengkelIn

final class RegionFitTests: XCTestCase {
    func testSingleValidCoordinate() {
        let region = MKCoordinateRegion.fitting(
            CLLocationCoordinate2D(latitude: -7.28, longitude: 112.63), nil)
        XCTAssertEqual(region.center.latitude, -7.28, accuracy: 0.0001)
        XCTAssertEqual(region.span.latitudeDelta, 0.02, accuracy: 0.0001)
    }

    func testInvalidFirstFallsBackToOrigin() {
        let region = MKCoordinateRegion.fitting(
            CLLocationCoordinate2D(latitude: .nan, longitude: .nan), nil)
        XCTAssertEqual(region.center.latitude, 0, accuracy: 0.0001)
        XCTAssertEqual(region.center.longitude, 0, accuracy: 0.0001)
    }

    func testClosePairUsesMidpoint() {
        let a = CLLocationCoordinate2D(latitude: -7.2845, longitude: 112.6315)
        let b = CLLocationCoordinate2D(latitude: -7.2905, longitude: 112.6360)
        let region = MKCoordinateRegion.fitting(a, b)
        XCTAssertEqual(region.center.latitude, (a.latitude + b.latitude) / 2, accuracy: 0.0001)
        XCTAssertEqual(region.center.longitude, (a.longitude + b.longitude) / 2, accuracy: 0.0001)
        XCTAssertTrue(region.span.latitudeDelta.isFinite)
        XCTAssertGreaterThanOrEqual(region.span.latitudeDelta, 0.005)
        XCTAssertLessThanOrEqual(region.span.latitudeDelta, 160)
        XCTAssertGreaterThanOrEqual(region.span.longitudeDelta, 0.005)
        XCTAssertLessThanOrEqual(region.span.longitudeDelta, 300)
    }

    func testFarPairFallsBackToFirst() {
        let surabaya = CLLocationCoordinate2D(latitude: -7.2845, longitude: 112.6315)
        let newYork = CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060)
        let region = MKCoordinateRegion.fitting(surabaya, newYork)
        XCTAssertEqual(region.center.latitude, -7.2845, accuracy: 0.0001)
        XCTAssertEqual(region.span.latitudeDelta, 0.02, accuracy: 0.0001)
    }
}
