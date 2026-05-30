//
//  MbengkelInWatchOS_Watch_AppTests.swift
//  MbengkelInWatchOS Watch AppTests
//

import XCTest
@testable import MbengkelInWatchOS_Watch_App

final class WatchOrderStateWatchTests: XCTestCase {
    func testRoundTrip() throws {
        let offer = WatchBidOffer(
            bidId: "b1", bengkelName: "Bengkel A", price: 75000, rating: 4.5)
        let state = WatchOrderState(
            hasActiveOrder: true, stage: "inProgress", serviceType: "Ban Gembos",
            bengkelName: "Bengkel A", agreedPrice: 75000, mySideCompleted: false,
            alreadyRated: false, requestId: "r1", offers: [offer])

        let data = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(WatchOrderState.self, from: data)
        XCTAssertEqual(decoded, state)
        XCTAssertEqual(offer.id, offer.bidId)
    }

    func testEmptyDefaults() {
        let empty = WatchOrderState.empty
        XCTAssertFalse(empty.hasActiveOrder)
        XCTAssertEqual(empty.stage, "finding")
        XCTAssertTrue(empty.offers.isEmpty)
    }

    func testContractDecodeFromPhonePayload() throws {
        let json = #"""
        {"hasActiveOrder":true,"stage":"inProgress","serviceType":"Ban Gembos",
        "bengkelName":"Bengkel A","agreedPrice":75000,"mySideCompleted":false,
        "alreadyRated":false,"requestId":"r1",
        "offers":[{"bidId":"b1","bengkelName":"Bengkel A","price":75000,"rating":4.5}]}
        """#
        let state = try JSONDecoder().decode(
            WatchOrderState.self, from: Data(json.utf8))
        XCTAssertEqual(state.stage, "inProgress")
        XCTAssertEqual(state.agreedPrice, 75000)
        XCTAssertEqual(state.requestId, "r1")
        XCTAssertEqual(state.offers.first?.bidId, "b1")
        XCTAssertEqual(state.offers.first?.rating, 4.5)
    }

    func testStageStringContract() {
        XCTAssertEqual("finding", WatchOrderState.empty.stage)
        let stages = ["finding", "inProgress", "finished"]
        XCTAssertEqual(stages.count, 3)
        XCTAssertTrue(stages.contains("inProgress"))
    }
}
