//
//  WatchOrderStateAppTests.swift
//  MbengkelInUnitTests
//

import XCTest
@testable import MbengkelIn

final class WatchOrderStateAppTests: XCTestCase {
    func testRoundTrip() throws {
        let offer = WatchBidOffer(
            bidId: "b1", bengkelName: "Bengkel A", price: 75000, rating: 4.5)
        let state = WatchOrderState(
            hasActiveOrder: true, stage: "inProgress", serviceType: "Ban Gembos",
            bengkelName: "Bengkel A", agreedPrice: 75000, mySideCompleted: false,
            canFinish: true, alreadyRated: false, requestId: "r1", offers: [offer])

        let data = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(WatchOrderState.self, from: data)
        XCTAssertEqual(decoded, state)
        XCTAssertTrue(decoded.canFinish)
        XCTAssertEqual(offer.id, offer.bidId)
    }

    func testEmptyDefaults() {
        let empty = WatchOrderState.empty
        XCTAssertFalse(empty.hasActiveOrder)
        XCTAssertEqual(empty.stage, "finding")
        XCTAssertTrue(empty.offers.isEmpty)
    }
}
