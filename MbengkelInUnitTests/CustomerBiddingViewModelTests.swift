import Testing
import Foundation
@testable import MbengkelIn

@Suite("CustomerBiddingViewModel") @MainActor
final class CustomerBiddingViewModelTests {
    @Test func nonTireMinPrice() async {
        let vm = CustomerBiddingViewModel(
            serviceType: .akiKering, latitude: 0, longitude: 0,
            tireCount: 1, photoUrls: [])
        #expect(vm.minPrice == 60000)
        #expect(vm.customerBidPrice == 60000)
        _ = consume vm
        await Task.yield()
    }

    @Test func tireMinPriceScalesWithCount() async {
        let vm = CustomerBiddingViewModel(
            serviceType: .banGembos, latitude: 0, longitude: 0,
            tireCount: 2, photoUrls: [])
        #expect(vm.minPrice == 50000)
        _ = consume vm
        await Task.yield()
    }

    @Test func resumingOrder() async throws {
        let json = #"""
        {"id":"r1","customer_id":"c1","service_type":"Ban Pecah",
        "latitude":-7.28,"longitude":112.63,"price":99000,"status":"To Do",
        "tire_count":2,"vehicle_id":"v9","vehicle_info":"Y"}
        """#
        let order = try JSONDecoder().decode(NearbyOrder.self, from: Data(json.utf8))
        let vm = CustomerBiddingViewModel(resuming: order)
        #expect(vm.serviceRequestId == "r1")
        #expect(vm.customerBidPrice == 99000)
        #expect(vm.isSearching)
        #expect(vm.vehicleId == "v9")
        #expect(vm.vehicleInfo == "Y")
        _ = consume vm
        await Task.yield()
    }
}
