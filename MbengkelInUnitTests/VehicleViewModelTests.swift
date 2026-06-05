//
//  VehicleViewModelTests.swift
//  MbengkelInUnitTests
//
//  Vehicle CRUD orchestration, driven through a mocked repository + auth.
//

import Testing
import Foundation
@testable import MbengkelIn

@Suite("VehicleViewModel") @MainActor
final class VehicleViewModelTests {
    private func makeVM(_ auth: MockAuthService, _ repo: MockVehicleRepository) -> VehicleViewModel {
        VehicleViewModel(authService: auth, vehicleRepository: repo)
    }

    @Test func addVehicleSuccessInsertsAndRefreshes() async {
        let auth = MockAuthService(); auth.sessionToReturn = AuthFixtures.session()
        let repo = MockVehicleRepository()
        let vm = makeVM(auth, repo)

        let ok = await vm.addVehicle(manufacturer: "Honda", model: "Beat",
                                     year: 2021, licensePlate: "B 1234 ABC", color: "Hitam")

        #expect(ok)
        #expect(repo.insertCallCount == 1)
        #expect(repo.lastInserted?.manufacturer == "Honda")
        #expect(repo.lastInserted?.customerId == AuthFixtures.defaultUID)
        #expect(vm.userVehicles.count == 1)
        #expect(vm.errorMessage == nil)
        #expect(vm.isLoading == false)
        _ = consume vm
        await Task.yield()
    }

    @Test func addVehicleFailureSetsError() async {
        let auth = MockAuthService(); auth.sessionToReturn = AuthFixtures.session()
        let repo = MockVehicleRepository(); repo.insertError = MockError(message: "DB down")
        let vm = makeVM(auth, repo)

        let ok = await vm.addVehicle(manufacturer: "Honda", model: "Beat",
                                     year: 2021, licensePlate: "B 1234 ABC", color: "Hitam")

        #expect(!ok)
        #expect(vm.errorMessage == "DB down")
        #expect(vm.userVehicles.isEmpty)
        #expect(vm.isLoading == false)
        _ = consume vm
        await Task.yield()
    }

    @Test func addVehicleWithoutSessionReturnsFalse() async {
        let auth = MockAuthService() // no session configured -> getCurrentSession throws
        let repo = MockVehicleRepository()
        let vm = makeVM(auth, repo)

        let ok = await vm.addVehicle(manufacturer: "Honda", model: "Beat",
                                     year: 2021, licensePlate: "B 1234 ABC", color: "Hitam")

        #expect(!ok)
        #expect(repo.insertCallCount == 0)
        #expect(vm.isLoading == false)
        _ = consume vm
        await Task.yield()
    }

    @Test func updateVehicleSuccessSendsPayload() async {
        let auth = MockAuthService(); auth.sessionToReturn = AuthFixtures.session()
        let repo = MockVehicleRepository()
        let vm = makeVM(auth, repo)

        let ok = await vm.updateVehicle(vehicleId: "v1", manufacturer: "Toyota", model: "Avanza",
                                        year: 2020, licensePlate: "L 9 XYZ", color: "Putih")

        #expect(ok)
        #expect(repo.updateCallCount == 1)
        #expect(repo.lastUpdatePayload?.manufacturer == "Toyota")
        #expect(repo.lastUpdatePayload?.license_plate == "L 9 XYZ")
        #expect(vm.successMessage == "Kendaraan berhasil diperbarui!")
        #expect(vm.isLoading == false)
        _ = consume vm
        await Task.yield()
    }

    @Test func updateVehicleFailureSetsError() async {
        let auth = MockAuthService(); auth.sessionToReturn = AuthFixtures.session()
        let repo = MockVehicleRepository(); repo.updateError = MockError(message: "update failed")
        let vm = makeVM(auth, repo)

        let ok = await vm.updateVehicle(vehicleId: "v1", manufacturer: "Toyota", model: "Avanza",
                                        year: 2020, licensePlate: "L 9 XYZ", color: "Putih")

        #expect(!ok)
        #expect(vm.errorMessage == "update failed")
        #expect(vm.isLoading == false)
        _ = consume vm
        await Task.yield()
    }

    @Test func deleteVehicleSuccessRemovesFromList() async {
        let auth = MockAuthService(); auth.sessionToReturn = AuthFixtures.session()
        let repo = MockVehicleRepository()
        repo.stored = [Vehicle(id: "v1", customerId: "c1", manufacturer: "Honda",
                               model: "Beat", year: 2021, licensePlate: "B 1 ABC",
                               color: "Hitam", createdAt: nil)]
        let vm = makeVM(auth, repo)

        let ok = await vm.deleteVehicle(vehicleId: "v1")

        #expect(ok)
        #expect(repo.deleteCallCount == 1)
        #expect(vm.userVehicles.isEmpty)
        _ = consume vm
        await Task.yield()
    }

    @Test func deleteVehicleFailureSetsError() async {
        let auth = MockAuthService(); auth.sessionToReturn = AuthFixtures.session()
        let repo = MockVehicleRepository(); repo.deleteError = MockError(message: "delete failed")
        let vm = makeVM(auth, repo)

        let ok = await vm.deleteVehicle(vehicleId: "v1")

        #expect(!ok)
        #expect(vm.errorMessage == "delete failed")
        _ = consume vm
        await Task.yield()
    }
}
