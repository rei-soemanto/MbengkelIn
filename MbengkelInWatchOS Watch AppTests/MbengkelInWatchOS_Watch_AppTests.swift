import Foundation
import Testing
@testable import MbengkelInWatchOS_Watch_App

@Suite("WatchOrderState (watchOS)")
struct WatchOrderStateWatchTests {
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

    @Test func contractDecodeFromPhonePayload() throws {
        let json = #"""
        {"hasActiveOrder":true,"stage":"inProgress","serviceType":"Ban Gembos",
        "bengkelName":"Bengkel A","agreedPrice":75000,"mySideCompleted":false,
        "canFinish":true,"alreadyRated":false,"requestId":"r1",
        "offers":[{"bidId":"b1","bengkelName":"Bengkel A","price":75000,"rating":4.5}]}
        """#
        let state = try JSONDecoder().decode(
            WatchOrderState.self, from: Data(json.utf8))
        #expect(state.stage == "inProgress")
        #expect(state.agreedPrice == 75000)
        #expect(state.canFinish)
        #expect(state.requestId == "r1")
        #expect(state.offers.first?.bidId == "b1")
        #expect(state.offers.first?.rating == 4.5)
    }

    @Test func stageStringContract() {
        #expect(WatchOrderState.empty.stage == "finding")
        let stages = ["finding", "inProgress", "finished"]
        #expect(stages.count == 3)
        #expect(stages.contains("inProgress"))
    }
}
