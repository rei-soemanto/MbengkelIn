//
//  OrderDTOTests.swift
//  MbengkelInUnitTests
//

import XCTest
@testable import MbengkelIn

final class OrderDTOTests: XCTestCase {
    func testServiceRequestPayloadEncoding() throws {
        let payload = ServiceRequestPayload(
            customer_id: "c1",
            service_type: .banGembos,
            description: "flat tire",
            latitude: -7.28,
            longitude: 112.63,
            price: 50000,
            is_emergency: true,
            status: "To Do",
            tire_count: 2,
            photo_urls: ["p"],
            vehicle_id: "v1",
            vehicle_info: "X"
        )
        let data = try JSONEncoder().encode(payload)
        let obj = try XCTUnwrap(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )

        for key in ["customer_id", "service_type", "vehicle_id", "vehicle_info",
                    "photo_urls", "tire_count", "is_emergency", "price",
                    "status", "description", "latitude", "longitude"] {
            XCTAssertNotNil(obj[key], "missing key \(key)")
        }
        XCTAssertEqual(obj["service_type"] as? String, "Ban Gembos")
        XCTAssertEqual(obj["vehicle_id"] as? String, "v1")
    }

    func testTodaysEarningRowWithPrice() throws {
        let row = try JSONDecoder().decode(
            TodaysEarningRow.self, from: Data(#"{"price":50000}"#.utf8))
        XCTAssertEqual(row.price, 50000)
    }

    func testTodaysEarningRowNullPrice() throws {
        let row = try JSONDecoder().decode(
            TodaysEarningRow.self, from: Data(#"{"price":null}"#.utf8))
        XCTAssertNil(row.price)
    }
}
