//
//  ModelDecodeTests.swift
//  MbengkelInUnitTests
//

import XCTest
@testable import MbengkelIn

final class ModelDecodeTests: XCTestCase {
    private let decoder = JSONDecoder()

    func testVehicleDecode() throws {
        let json = #"""
        {"id":"v1","customer_id":"c1","manufacturer":"Honda","model":"Beat",
        "year":2021,"license_plate":"B 1234 ABC","color":"Hitam"}
        """#
        let vehicle = try decoder.decode(Vehicle.self, from: Data(json.utf8))
        XCTAssertEqual(vehicle.id, "v1")
        XCTAssertEqual(vehicle.customerId, "c1")
        XCTAssertEqual(vehicle.manufacturer, "Honda")
        XCTAssertEqual(vehicle.model, "Beat")
        XCTAssertEqual(vehicle.year, 2021)
        XCTAssertEqual(vehicle.licensePlate, "B 1234 ABC")
        XCTAssertEqual(vehicle.color, "Hitam")
    }

    func testOrderLocationDecode() throws {
        let json = #"""
        {"service_request_id":"r1","provider_uid":"p1","latitude":-7.28,
        "longitude":112.63,"updated_at":"2026-06-03T10:00:00Z"}
        """#
        let location = try decoder.decode(OrderLocation.self, from: Data(json.utf8))
        XCTAssertEqual(location.serviceRequestId, "r1")
        XCTAssertEqual(location.providerUid, "p1")
        XCTAssertEqual(location.latitude, -7.28)
        XCTAssertEqual(location.longitude, 112.63)
        XCTAssertEqual(location.updatedAt, "2026-06-03T10:00:00Z")
        XCTAssertEqual(location.id, "r1")
    }

    func testChatMessageFull() throws {
        let json = #"""
        {"id":"m1","service_request_id":"r1","sender_id":"s1",
        "content":"Halo","image_url":"https://x/y.jpg","created_at":"2026-06-03T10:00:00Z"}
        """#
        let message = try decoder.decode(ChatMessage.self, from: Data(json.utf8))
        XCTAssertEqual(message.id, "m1")
        XCTAssertEqual(message.serviceRequestId, "r1")
        XCTAssertEqual(message.senderId, "s1")
        XCTAssertEqual(message.content, "Halo")
        XCTAssertEqual(message.imageUrl, "https://x/y.jpg")
        XCTAssertEqual(message.createdAt, "2026-06-03T10:00:00Z")
    }

    func testChatMessageWithoutContentAndImage() throws {
        let json = #"{"id":"m2","service_request_id":"r1","sender_id":"s1"}"#
        let message = try decoder.decode(ChatMessage.self, from: Data(json.utf8))
        XCTAssertNil(message.content)
        XCTAssertNil(message.imageUrl)
        XCTAssertNil(message.createdAt)
        XCTAssertEqual(message.senderId, "s1")
    }
}
