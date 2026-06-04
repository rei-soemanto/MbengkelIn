import Testing
import Foundation
@testable import MbengkelIn

@Suite("WatchOrderState (iOS)")
@MainActor struct WatchOrderStateAppTests {
    @Test func roundTrip() throws {
        let offer = WatchBidOffer(
            bidId: "b1", bengkelName: "Bengkel A", price: 75000, rating: 4.5)
        let state = WatchOrderState(
            hasActiveOrder: true, stage: "inProgress", serviceType: "Ban Gembos",
            bengkelName: "Bengkel A", agreedPrice: 75000, mySideCompleted: false,
            canFinish: true, alreadyRated: false, requestId: "r1", offers: [offer])

        let data = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(WatchOrderState.self, from: data)
        #expect(decoded == state)
        #expect(decoded.canFinish)
        #expect(offer.id == offer.bidId)
    }

    @Test func emptyDefaults() {
        let empty = WatchOrderState.empty
        #expect(!empty.hasActiveOrder)
        #expect(empty.stage == "finding")
        #expect(empty.offers.isEmpty)
    }
}
