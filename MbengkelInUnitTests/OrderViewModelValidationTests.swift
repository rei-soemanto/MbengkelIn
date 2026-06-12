//
//  OrderViewModelValidationTests.swift
//  MbengkelInUnitTests
//
//  Pure, backend-free validation logic in OrderViewModel.createOrder() — every
//  guard runs before any network/storage call, so the failure ladder is fully
//  deterministic without touching Supabase.
//

import Testing
import Foundation
@testable import MbengkelIn

@Suite("OrderViewModelValidation") @MainActor
final class OrderViewModelValidationTests {

    private func vehicle(id: String) -> Vehicle {
        Vehicle(id: id, customerId: "c1", manufacturer: "Honda", model: "Beat",
                year: 2021, licensePlate: "B 1 ABC", color: "Hitam", createdAt: nil)
    }

    // No service selected -> createOrder returns silently, nothing happens.
    @Test func createOrderWithoutServiceIsNoOp() async {
        let vm = OrderViewModel()
        vm.createOrder()
        #expect(vm.errorMessage == nil)
        #expect(vm.navigateToBidding == false)
        _ = consume vm
        await Task.yield()
    }

    // Service + address present but location never resolved -> location error.
    @Test func createOrderWithoutResolvedLocationErrors() async {
        let vm = OrderViewModel()
        vm.selectService("Aki Kering")
        vm.locationAddress = "Jl. Test 1"
        // hasResolvedLocation stays false
        vm.createOrder()
        #expect(vm.errorMessage == "Tentukan lokasi kamu dulu (gunakan lokasi saat ini, geser peta, atau cari alamat).")
        #expect(vm.navigateToBidding == false)
        _ = consume vm
        await Task.yield()
    }

    // Resolved location, valid service, but no vehicle exists -> prompt to add one.
    @Test func createOrderWithoutAnyVehicleErrors() async {
        let vm = OrderViewModel()
        vm.selectService("Aki Kering")
        vm.locationAddress = "Jl. Test 1"
        vm.hasResolvedLocation = true
        vm.createOrder()
        #expect(vm.errorMessage == "Tambahkan kendaraan di menu Profil terlebih dahulu.")
        #expect(vm.navigateToBidding == false)
        _ = consume vm
        await Task.yield()
    }

    // Vehicles exist but none selected -> prompt to pick the affected vehicle.
    @Test func createOrderWithoutSelectedVehicleErrors() async {
        let vm = OrderViewModel()
        vm.selectService("Aki Kering")
        vm.locationAddress = "Jl. Test 1"
        vm.hasResolvedLocation = true
        vm.vehicles = [vehicle(id: "v1")]
        // selectedVehicleId stays nil
        vm.createOrder()
        #expect(vm.errorMessage == "Pilih kendaraan yang bermasalah.")
        #expect(vm.navigateToBidding == false)
        _ = consume vm
        await Task.yield()
    }

    // Tire service with a valid vehicle but missing tire photos -> photo error.
    @Test func createOrderTireServiceMissingPhotosErrors() async {
        let vm = OrderViewModel()
        vm.selectService("Ban Gembos")   // requiresTireCount == true, tireCount resets to 1
        vm.locationAddress = "Jl. Test 1"
        vm.hasResolvedLocation = true
        vm.vehicles = [vehicle(id: "v1")]
        vm.selectedVehicleId = "v1"
        // photosData == [nil] -> zero real photos for tireCount 1
        vm.createOrder()
        #expect(vm.errorMessage == "Mohon sertakan 1 foto kondisi ban (satu per ban).")
        #expect(vm.navigateToBidding == false)
        _ = consume vm
        await Task.yield()
    }

    // requiresTireCount reflects the selected service type.
    @Test func requiresTireCountTracksServiceType() async {
        let vm = OrderViewModel()
        #expect(vm.requiresTireCount == false)        // nothing selected
        vm.selectService("Aki Kering")
        #expect(vm.requiresTireCount == false)
        vm.selectService("Ban Gembos")
        #expect(vm.requiresTireCount == true)
        _ = consume vm
        await Task.yield()
    }

    // cancelLoading() returns the loading phase to idle.
    @Test func cancelLoadingResetsPhase() async {
        let vm = OrderViewModel()
        vm.loadingPhase = .loading(message: "...")
        vm.cancelLoading()
        if case .idle = vm.loadingPhase {} else {
            Issue.record("loadingPhase should be .idle after cancelLoading()")
        }
        _ = consume vm
        await Task.yield()
    }
}
