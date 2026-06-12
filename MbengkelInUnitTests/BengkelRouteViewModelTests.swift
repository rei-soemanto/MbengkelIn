//
//  BengkelRouteViewModelTests.swift
//  MbengkelInUnitTests
//
//  status mirrors the tracked order (defaulting to "To Do" before one loads).
//  This is the only fully backend-free surface on the bengkel route screen.
//

import Testing
import Foundation
@testable import MbengkelIn

@Suite("BengkelRouteViewModel") @MainActor
final class BengkelRouteViewModelTests {

    private func order(status: String) throws -> NearbyOrder {
        let json = """
        {"id":"r1","customer_id":"c1","latitude":-7.28,"longitude":112.63,"status":"\(status)"}
        """
        return try JSONDecoder().decode(NearbyOrder.self, from: Data(json.utf8))
    }

    @Test func statusDefaultsToToDoBeforeOrderLoads() async {
        let vm = BengkelRouteViewModel()
        #expect(vm.status == "To Do")
        _ = consume vm
        await Task.yield()
    }

    @Test func statusReflectsLoadedOrder() async throws {
        let vm = BengkelRouteViewModel()
        vm.order = try order(status: "On Progress")
        #expect(vm.status == "On Progress")
        vm.order = try order(status: "Done")
        #expect(vm.status == "Done")
        _ = consume vm
        await Task.yield()
    }
}
