//
//  MoneyIntegrityDTOTests.swift
//  MbengkelInUnitTests
//

import XCTest
@testable import MbengkelIn

// Encoding contracts for the server-authoritative RPC param DTOs introduced by
// the money-integrity work. The snake_case keys must match the Postgres RPC
// argument names exactly, or the rpc() call silently misbinds.
final class MoneyIntegrityDTOTests: XCTestCase {
    private func json(_ value: Encodable) throws -> [String: Any] {
        let data = try JSONEncoder().encode(value)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    func testAcceptBidParams() throws {
        let obj = try json(AcceptBidParams(p_bid_id: "bid-1"))
        XCTAssertEqual(obj["p_bid_id"] as? String, "bid-1")
        XCTAssertEqual(obj.count, 1)
    }

    func testCancelOrderParams() throws {
        let obj = try json(CancelOrderParams(p_request_id: "req-1"))
        XCTAssertEqual(obj["p_request_id"] as? String, "req-1")
        XCTAssertEqual(obj.count, 1)
    }

    func testRateOrderParamsWithReview() throws {
        let obj = try json(RateOrderParams(p_request_id: "req-2", p_rating: 5, p_review: "Mantap"))
        XCTAssertEqual(obj["p_request_id"] as? String, "req-2")
        XCTAssertEqual(obj["p_rating"] as? Int, 5)
        XCTAssertEqual(obj["p_review"] as? String, "Mantap")
    }

    func testRateOrderParamsNilReviewOmitsKey() throws {
        let obj = try json(RateOrderParams(p_request_id: "req-3", p_rating: 4, p_review: nil))
        XCTAssertEqual(obj["p_rating"] as? Int, 4)
        XCTAssertNil(obj["p_review"], "nil review must be omitted, not sent as null-key")
    }

    func testMarkCompletedParamsWithPhoto() throws {
        let obj = try json(MarkCompletedParams(p_request_id: "req-4", p_completion_photo_url: "https://x/y.jpg"))
        XCTAssertEqual(obj["p_request_id"] as? String, "req-4")
        XCTAssertEqual(obj["p_completion_photo_url"] as? String, "https://x/y.jpg")
    }

    func testMarkCompletedParamsNilPhotoOmitsKey() throws {
        let obj = try json(MarkCompletedParams(p_request_id: "req-5", p_completion_photo_url: nil))
        XCTAssertEqual(obj["p_request_id"] as? String, "req-5")
        XCTAssertNil(obj["p_completion_photo_url"])
    }
}
