//
//  CustomerBiddingViewModelTests.swift
//  MbengkelInUnitTests
//

import XCTest
@testable import MbengkelIn

@MainActor
final class CustomerBiddingViewModelTests: XCTestCase {
    private var vm: CustomerBiddingViewModel!

    override func tearDown() async throws {
        vm = nil
        await Task.yield()
    }

    func testNonTireMinPrice() async {
        vm = CustomerBiddingViewModel(
            serviceType: .akiKering, latitude: 0, longitude: 0,
            tireCount: 1, photoUrls: [])
        XCTAssertEqual(vm.minPrice, 60000)
        XCTAssertEqual(vm.customerBidPrice, 60000)
    }

    func testTireMinPriceScalesWithCount() async {
        vm = CustomerBiddingViewModel(
            serviceType: .banGembos, latitude: 0, longitude: 0,
            tireCount: 2, photoUrls: [])
        XCTAssertEqual(vm.minPrice, 50000)
    }

    func testResumingOrder() async throws {
        let json = #"""
        {"id":"r1","customer_id":"c1","service_type":"Ban Pecah",
        "latitude":-7.28,"longitude":112.63,"price":99000,"status":"To Do",
        "tire_count":2,"vehicle_id":"v9","vehicle_info":"Y"}
        """#
        let order = try JSONDecoder().decode(NearbyOrder.self, from: Data(json.utf8))
        vm = CustomerBiddingViewModel(resuming: order)
        XCTAssertEqual(vm.serviceRequestId, "r1")
        XCTAssertEqual(vm.customerBidPrice, 99000)
        XCTAssertTrue(vm.isSearching)
        XCTAssertEqual(vm.vehicleId, "v9")
        XCTAssertEqual(vm.vehicleInfo, "Y")
    }
}
