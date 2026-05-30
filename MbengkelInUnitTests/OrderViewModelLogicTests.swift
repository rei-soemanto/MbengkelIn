//
//  OrderViewModelLogicTests.swift
//  MbengkelInUnitTests
//

import XCTest
@testable import MbengkelIn

@MainActor
final class OrderViewModelLogicTests: XCTestCase {
    private var vm: OrderViewModel!

    override func setUp() async throws {
        vm = OrderViewModel()
    }

    override func tearDown() async throws {
        vm = nil
        await Task.yield()
    }

    func testSelectNonTireService() async {
        vm.selectService("Aki Kering")
        XCTAssertEqual(vm.estimatedPrice, 60000)
        XCTAssertFalse(vm.requiresTireCount)
    }

    func testSelectTireServiceAndTireCount() async {
        vm.selectService("Ban Gembos")
        XCTAssertEqual(vm.estimatedPrice, 25000)
        XCTAssertTrue(vm.requiresTireCount)

        vm.setTireCount(3)
        XCTAssertEqual(vm.estimatedPrice, 75000)
        XCTAssertEqual(vm.photosData.count, 3)

        vm.setTireCount(9)
        XCTAssertEqual(vm.tireCount, 4)

        vm.setTireCount(0)
        XCTAssertEqual(vm.tireCount, 1)
    }

    func testPrepareForNewOrderResets() async {
        vm.selectService("Ban Pecah")
        vm.setTireCount(2)
        vm.selectedVehicleId = "v1"

        vm.prepareForNewOrder()
        XCTAssertNil(vm.selectedService)
        XCTAssertEqual(vm.estimatedPrice, 0)
        XCTAssertNil(vm.selectedVehicleId)
        XCTAssertEqual(vm.tireCount, 1)
    }
}
