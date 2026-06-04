import Testing
@testable import MbengkelIn

@Suite("OrderViewModelLogic") @MainActor
final class OrderViewModelLogicTests {
    @Test func selectNonTireService() async {
        let vm = OrderViewModel()
        vm.selectService("Aki Kering")
        #expect(vm.estimatedPrice == 60000)
        #expect(!vm.requiresTireCount)
        _ = consume vm
        await Task.yield()
    }

    @Test func selectTireServiceAndTireCount() async {
        let vm = OrderViewModel()
        vm.selectService("Ban Gembos")
        #expect(vm.estimatedPrice == 25000)
        #expect(vm.requiresTireCount)

        vm.setTireCount(3)
        #expect(vm.estimatedPrice == 75000)
        #expect(vm.photosData.count == 3)

        vm.setTireCount(9)
        #expect(vm.tireCount == 4)

        vm.setTireCount(0)
        #expect(vm.tireCount == 1)
        _ = consume vm
        await Task.yield()
    }

    @Test func prepareForNewOrderResets() async {
        let vm = OrderViewModel()
        vm.selectService("Ban Pecah")
        vm.setTireCount(2)
        vm.selectedVehicleId = "v1"

        vm.prepareForNewOrder()
        #expect(vm.selectedService == nil)
        #expect(vm.estimatedPrice == 0)
        #expect(vm.selectedVehicleId == nil)
        #expect(vm.tireCount == 1)
        _ = consume vm
        await Task.yield()
    }
}
