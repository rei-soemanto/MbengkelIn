import Testing
import Foundation
@testable import MbengkelIn

@Suite("MoneyIntegrityDTO")
@MainActor struct MoneyIntegrityDTOTests {
    private func json(_ value: Encodable) throws -> [String: Any] {
        let data = try JSONEncoder().encode(value)
        return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    @Test func acceptBidParams() throws {
        let obj = try json(AcceptBidParams(p_bid_id: "bid-1"))
        #expect(obj["p_bid_id"] as? String == "bid-1")
        #expect(obj.count == 1)
    }

    @Test func cancelOrderParams() throws {
        let obj = try json(CancelOrderParams(p_request_id: "req-1"))
        #expect(obj["p_request_id"] as? String == "req-1")
        #expect(obj.count == 1)
    }

    @Test func rateOrderParamsWithReview() throws {
        let obj = try json(RateOrderParams(p_request_id: "req-2", p_rating: 5, p_review: "Mantap"))
        #expect(obj["p_request_id"] as? String == "req-2")
        #expect(obj["p_rating"] as? Int == 5)
        #expect(obj["p_review"] as? String == "Mantap")
    }

    @Test func rateOrderParamsNilReviewOmitsKey() throws {
        let obj = try json(RateOrderParams(p_request_id: "req-3", p_rating: 4, p_review: nil))
        #expect(obj["p_rating"] as? Int == 4)
        #expect(obj["p_review"] == nil)
    }

    @Test func markCompletedParamsWithPhoto() throws {
        let obj = try json(MarkCompletedParams(p_request_id: "req-4", p_completion_photo_url: "https://x/y.jpg"))
        #expect(obj["p_request_id"] as? String == "req-4")
        #expect(obj["p_completion_photo_url"] as? String == "https://x/y.jpg")
    }

    @Test func markCompletedParamsNilPhotoOmitsKey() throws {
        let obj = try json(MarkCompletedParams(p_request_id: "req-5", p_completion_photo_url: nil))
        #expect(obj["p_request_id"] as? String == "req-5")
        #expect(obj["p_completion_photo_url"] == nil)
    }
}
