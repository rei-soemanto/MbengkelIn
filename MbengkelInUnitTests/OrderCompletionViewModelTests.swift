//
//  OrderCompletionViewModelTests.swift
//  MbengkelInUnitTests
//
//  Pure completion-state derivation: status / isFinished / mySideCompleted are
//  computed from the decoded order and the customer-vs-provider role, with no
//  backend involved.
//

import Testing
import Foundation
@testable import MbengkelIn

@Suite("OrderCompletionViewModel") @MainActor
final class OrderCompletionViewModelTests {

    private func order(status: String,
                       customerCompleted: Bool = false,
                       providerCompleted: Bool = false) throws -> NearbyOrder {
        let json = """
        {"id":"r1","customer_id":"c1","latitude":-7.28,"longitude":112.63,
         "status":"\(status)","customer_completed":\(customerCompleted),
         "provider_completed":\(providerCompleted)}
        """
        return try JSONDecoder().decode(NearbyOrder.self, from: Data(json.utf8))
    }

    @Test func defaultsBeforeAnyOrderLoaded() async {
        let vm = OrderCompletionViewModel(requestId: "r1", isCustomer: true)
        #expect(vm.status == "On Progress")
        #expect(vm.isFinished == false)
        #expect(vm.mySideCompleted == false)
        _ = consume vm
        await Task.yield()
    }

    @Test func doneAndCancelledCountAsFinished() async throws {
        let vm = OrderCompletionViewModel(requestId: "r1", isCustomer: true)
        vm.order = try order(status: "Done")
        #expect(vm.status == "Done")
        #expect(vm.isFinished == true)

        vm.order = try order(status: "Cancelled")
        #expect(vm.isFinished == true)
        _ = consume vm
        await Task.yield()
    }

    @Test func mySideCompletedUsesCustomerFlagForCustomer() async throws {
        let vm = OrderCompletionViewModel(requestId: "r1", isCustomer: true)
        // Only the provider has finished -> customer's own side is not done yet.
        vm.order = try order(status: "On Progress", customerCompleted: false, providerCompleted: true)
        #expect(vm.mySideCompleted == false)

        vm.order = try order(status: "On Progress", customerCompleted: true, providerCompleted: false)
        #expect(vm.mySideCompleted == true)
        _ = consume vm
        await Task.yield()
    }

    @Test func mySideCompletedUsesProviderFlagForProvider() async throws {
        let vm = OrderCompletionViewModel(requestId: "r1", isCustomer: false)
        vm.order = try order(status: "On Progress", customerCompleted: true, providerCompleted: false)
        #expect(vm.mySideCompleted == false)

        vm.order = try order(status: "On Progress", customerCompleted: false, providerCompleted: true)
        #expect(vm.mySideCompleted == true)
        _ = consume vm
        await Task.yield()
    }
}
