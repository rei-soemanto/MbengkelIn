//
//  BengkelViewModelTests.swift
//  MbengkelInUnitTests
//
//  Bengkel register/update + offered-service CRUD, through mocked auth + repo.
//

import Testing
import Foundation
@testable import MbengkelIn

@Suite("BengkelViewModel") @MainActor
final class BengkelViewModelTests {
    private func makeVM(_ auth: MockAuthService, _ repo: MockBengkelRepository) -> BengkelViewModel {
        BengkelViewModel(authService: auth, bengkelRepository: repo)
    }

    private func sampleBengkel(services: [BengkelService] = []) -> Bengkel {
        Bengkel(id: "b1", providerUid: "p1", name: "Bengkel Lama", address: "Alamat Lama",
                latitude: 0, longitude: 0, status: "Verified", offeredServices: services,
                averageRating: 0, totalReviews: 0, createdAt: nil)
    }

    // MARK: Register

    @Test func registerBengkelSuccess() async {
        let auth = MockAuthService(); auth.sessionToReturn = AuthFixtures.session()
        let repo = MockBengkelRepository()
        let vm = makeVM(auth, repo)

        let ok = await vm.registerBengkel(name: "Bengkel Jaya", address: "Jl. Mawar 1")

        #expect(ok)
        #expect(repo.insertCallCount == 1)
        #expect(repo.lastInserted?.name == "Bengkel Jaya")
        #expect(repo.lastInserted?.providerUid == AuthFixtures.defaultUID)
        #expect(repo.lastInserted?.status == "Pending")
        #expect(vm.successMessage != nil)
        #expect(vm.errorMessage == nil)
        #expect(vm.isLoading == false)
        _ = consume vm
        await Task.yield()
    }

    @Test func registerBengkelRequiresSession() async {
        let auth = MockAuthService() // no session -> getCurrentSession throws
        let repo = MockBengkelRepository()
        let vm = makeVM(auth, repo)

        let ok = await vm.registerBengkel(name: "X", address: "Y")

        #expect(!ok)
        #expect(repo.insertCallCount == 0)
        #expect(vm.errorMessage == "Anda harus masuk untuk mendaftarkan Bengkel.")
        _ = consume vm
        await Task.yield()
    }

    @Test func registerBengkelInsertFailure() async {
        let auth = MockAuthService(); auth.sessionToReturn = AuthFixtures.session()
        let repo = MockBengkelRepository(); repo.insertError = MockError(message: "insert failed")
        let vm = makeVM(auth, repo)

        let ok = await vm.registerBengkel(name: "X", address: "Y")

        #expect(!ok)
        #expect(vm.errorMessage == "insert failed")
        #expect(vm.isLoading == false)
        _ = consume vm
        await Task.yield()
    }

    // MARK: Update

    @Test func updateBengkelSuccessSendsPayload() async {
        let auth = MockAuthService()
        let repo = MockBengkelRepository()
        let vm = makeVM(auth, repo)

        let ok = await vm.updateBengkel(bengkelId: "b1", name: "Bengkel Baru", address: "Alamat Baru")

        #expect(ok)
        #expect(repo.updateCallCount == 1)
        #expect(repo.lastUpdatePayload?.name == "Bengkel Baru")
        #expect(repo.lastUpdatePayload?.address == "Alamat Baru")
        #expect(vm.isLoading == false)
        _ = consume vm
        await Task.yield()
    }

    @Test func updateBengkelFailureSetsError() async {
        let auth = MockAuthService()
        let repo = MockBengkelRepository(); repo.updateError = MockError(message: "update failed")
        let vm = makeVM(auth, repo)

        let ok = await vm.updateBengkel(bengkelId: "b1", name: "X", address: "Y")

        #expect(!ok)
        #expect(vm.errorMessage == "update failed")
        _ = consume vm
        await Task.yield()
    }

    // MARK: Service CRUD

    @Test func addServiceAppendsAndPersists() async {
        let auth = MockAuthService()
        let repo = MockBengkelRepository()
        let vm = makeVM(auth, repo)
        vm.myBengkel = sampleBengkel()

        let ok = await vm.addService(bengkelId: "b1", serviceType: .akiKering, isActive: true)

        #expect(ok)
        #expect(vm.myBengkel?.offeredServices.count == 1)
        #expect(vm.myBengkel?.offeredServices.first?.serviceType == .akiKering)
        #expect(repo.updateServicesCallCount == 1)
        #expect(repo.lastServicesPayload?.offered_services.count == 1)
        _ = consume vm
        await Task.yield()
    }

    @Test func addServiceWithoutBengkelFails() async {
        let vm = makeVM(MockAuthService(), MockBengkelRepository())

        let ok = await vm.addService(bengkelId: "b1", serviceType: .akiKering, isActive: true)

        #expect(!ok)
        #expect(vm.errorMessage == "Data bengkel tidak ditemukan.")
        _ = consume vm
        await Task.yield()
    }

    @Test func updateServiceMutatesExisting() async {
        let repo = MockBengkelRepository()
        let vm = makeVM(MockAuthService(), repo)
        let existing = BengkelService(serviceType: .banGembos, isActive: true)
        vm.myBengkel = sampleBengkel(services: [existing])

        let ok = await vm.updateService(bengkelId: "b1", serviceId: existing.id,
                                        serviceType: .banPecah, isActive: false)

        #expect(ok)
        #expect(vm.myBengkel?.offeredServices.first?.serviceType == .banPecah)
        #expect(vm.myBengkel?.offeredServices.first?.isActive == false)
        #expect(repo.updateServicesCallCount == 1)
        _ = consume vm
        await Task.yield()
    }

    @Test func deleteServiceRemovesMatching() async {
        let repo = MockBengkelRepository()
        let vm = makeVM(MockAuthService(), repo)
        let s1 = BengkelService(serviceType: .banGembos, isActive: true)
        let s2 = BengkelService(serviceType: .akiKering, isActive: true)
        vm.myBengkel = sampleBengkel(services: [s1, s2])

        let ok = await vm.deleteService(bengkelId: "b1", serviceId: s1.id)

        #expect(ok)
        #expect(vm.myBengkel?.offeredServices.count == 1)
        #expect(vm.myBengkel?.offeredServices.first?.serviceType == .akiKering)
        #expect(repo.updateServicesCallCount == 1)
        _ = consume vm
        await Task.yield()
    }

    @Test func deleteBengkelSuccessClearsState() async {
        let auth = MockAuthService(); auth.sessionToReturn = AuthFixtures.session()
        let repo = MockBengkelRepository()
        let vm = makeVM(auth, repo)
        vm.myBengkel = sampleBengkel()

        let ok = await vm.deleteBengkel(bengkelId: "b1", password: "pw", email: "e@x.com")

        #expect(ok)
        #expect(repo.deleteCallCount == 1)
        #expect(vm.myBengkel == nil)
        _ = consume vm
        await Task.yield()
    }
}
