//
//  CustomerBiddingExtraTests.swift
//  MbengkelInUnitTests
//
//  Additional CustomerBiddingViewModel coverage beyond min-price/resume:
//  the startSearch min-price guard (returns before any backend call), the
//  search-progress math, and the ISO8601 timestamp parser used to schedule
//  bid expiry. (minPrice + resuming are covered in CustomerBiddingViewModelTests.)
//

import Testing
import Foundation
@testable import MbengkelIn

@Suite("CustomerBiddingExtra") @MainActor
final class CustomerBiddingExtraTests {

    private func makeVM() -> CustomerBiddingViewModel {
        CustomerBiddingViewModel(serviceType: .akiKering, latitude: 0, longitude: 0,
                                 tireCount: 1, photoUrls: [])
    }

    // Bidding below the derived minimum is rejected before any network work.
    @Test func startSearchBelowMinPriceIsRejected() async {
        let vm = makeVM()            // minPrice == 60_000 for Aki Kering
        await vm.startSearch(price: 1_000)
        #expect(vm.errorMessage?.contains("minimal") == true)
        #expect(vm.isStartingSearch == false)
        #expect(vm.serviceRequestId == nil)
        _ = consume vm
        await Task.yield()
    }

    // Countdown progress is remaining / total, guarded against divide-by-zero.
    @Test func searchProgressReflectsRemainingFraction() async {
        let vm = makeVM()
        #expect(vm.searchTotalSeconds == 120)
        #expect(vm.searchProgress == 0)            // remaining defaults to 0
        vm.searchSecondsRemaining = 60
        #expect(abs(vm.searchProgress - 0.5) < 0.0001)
        vm.searchSecondsRemaining = 120
        #expect(abs(vm.searchProgress - 1.0) < 0.0001)
        _ = consume vm
        await Task.yield()
    }

    // raisePrice() drops out of the searching state so the customer can re-bid.
    @Test func raisePriceLeavesSearchingState() async {
        let vm = makeVM()
        vm.isSearching = true
        vm.raisePrice()
        #expect(vm.isSearching == false)
        #expect(vm.showRetryPrompt == false)
        _ = consume vm
        await Task.yield()
    }

    // MARK: parseISODate

    @Test func parseISODateAcceptsFractionalSeconds() {
        #expect(CustomerBiddingViewModel.parseISODate("2026-06-12T10:00:00.123456Z") != nil)
    }

    @Test func parseISODateAcceptsPlainInternetDateTime() {
        #expect(CustomerBiddingViewModel.parseISODate("2026-06-12T10:00:00Z") != nil)
    }

    @Test func parseISODateAcceptsFractionalWithOffset() {
        #expect(CustomerBiddingViewModel.parseISODate("2026-06-12T17:00:00.123+07:00") != nil)
    }

    @Test func parseISODateRejectsGarbage() {
        #expect(CustomerBiddingViewModel.parseISODate("not-a-date") == nil)
    }
}
