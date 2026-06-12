//
//  OrderRatingViewModelTests.swift
//  MbengkelInUnitTests
//
//  The star-count guard in submit() runs before any repository call, so an
//  out-of-range rating is rejected deterministically without a backend.
//

import Testing
import Foundation
@testable import MbengkelIn

@Suite("OrderRatingViewModel") @MainActor
final class OrderRatingViewModelTests {

    @Test func zeroStarsIsRejected() async {
        let vm = OrderRatingViewModel()
        let ok = await vm.submit(requestId: "r1", rating: 0, review: "")
        #expect(ok == false)
        #expect(vm.errorMessage == "Pilih jumlah bintang terlebih dahulu.")
        #expect(vm.isSubmitting == false)
        _ = consume vm
        await Task.yield()
    }

    @Test func aboveFiveStarsIsRejected() async {
        let vm = OrderRatingViewModel()
        let ok = await vm.submit(requestId: "r1", rating: 6, review: "bagus")
        #expect(ok == false)
        #expect(vm.errorMessage == "Pilih jumlah bintang terlebih dahulu.")
        _ = consume vm
        await Task.yield()
    }

    @Test func negativeRatingIsRejected() async {
        let vm = OrderRatingViewModel()
        let ok = await vm.submit(requestId: "r1", rating: -3, review: "")
        #expect(ok == false)
        _ = consume vm
        await Task.yield()
    }
}
