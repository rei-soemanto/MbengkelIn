//
//  ModelCodableTests.swift
//  MbengkelInUnitTests
//

import XCTest
@testable import MbengkelIn

final class ModelCodableTests: XCTestCase {
    private let decoder = JSONDecoder()

    func testUserWithHeldBalance() throws {
        let json = #"{"id":"u1","name":"Budi","balance":100000,"held_balance":30000,"role":"USER"}"#
        let user = try decoder.decode(User.self, from: Data(json.utf8))
        XCTAssertEqual(user.balance, 100000)
        XCTAssertEqual(user.heldBalance, 30000)
        XCTAssertEqual(user.availableBalance, 70000)
        XCTAssertNil(user.email)
        XCTAssertNil(user.phoneNumber)
    }

    func testUserWithoutHeldBalance() throws {
        let json = #"{"id":"u2","name":"Ani","balance":50000,"role":"USER"}"#
        let user = try decoder.decode(User.self, from: Data(json.utf8))
        XCTAssertNil(user.heldBalance)
        XCTAssertEqual(user.availableBalance, user.balance)
    }

    func testNearbyOrderFull() throws {
        let json = #"""
        {"id":"r1","customer_id":"c1","service_type":"Ban Gembos","latitude":-7.28,
        "longitude":112.63,"status":"To Do","tire_count":2,"photo_urls":["a","b"],
        "customer_completed":true,"vehicle_id":"v1","vehicle_info":"Honda Beat • B 1 ABC"}
        """#
        let order = try decoder.decode(NearbyOrder.self, from: Data(json.utf8))
        XCTAssertEqual(order.serviceType, "Ban Gembos")
        XCTAssertEqual(order.tireCount, 2)
        XCTAssertEqual(order.photoUrls?.count, 2)
        XCTAssertEqual(order.vehicleId, "v1")
        XCTAssertEqual(order.vehicleInfo, "Honda Beat • B 1 ABC")
        XCTAssertEqual(order.customerCompleted, true)
    }

    func testNearbyOrderMinimal() throws {
        let json = #"{"id":"r2","customer_id":"c2","latitude":0,"longitude":0,"status":"To Do"}"#
        let order = try decoder.decode(NearbyOrder.self, from: Data(json.utf8))
        XCTAssertNil(order.serviceType)
        XCTAssertNil(order.tireCount)
        XCTAssertNil(order.photoUrls)
        XCTAssertNil(order.vehicleId)
        XCTAssertNil(order.price)
    }

    func testBengkelDecode() throws {
        let json = #"""
        {"id":"b1","provider_uid":"p1","name":"Bengkel A","address":"Jl X",
        "latitude":-7.2,"longitude":112.6,"status":"Verified","offered_services":[],
        "average_rating":4.5,"total_reviews":10}
        """#
        let bengkel = try decoder.decode(Bengkel.self, from: Data(json.utf8))
        XCTAssertEqual(bengkel.averageRating, 4.5)
        XCTAssertEqual(bengkel.totalReviews, 10)
        XCTAssertTrue(bengkel.offeredServices.isEmpty)
        XCTAssertEqual(bengkel.providerUid, "p1")
    }

    func testBidWithNestedBengkel() throws {
        let json = #"""
        {"id":"bid1","service_request_id":"r1","provider_uid":"p1","bengkel_id":"b1",
        "price":75000,"status":"Pending","bengkel":{"id":"b1","provider_uid":"p1",
        "name":"Bengkel A","address":"Jl X","latitude":-7.2,"longitude":112.6,
        "status":"Verified","offered_services":[],"average_rating":4.0,"total_reviews":3}}
        """#
        let bid = try decoder.decode(Bid.self, from: Data(json.utf8))
        XCTAssertEqual(bid.price, 75000)
        XCTAssertEqual(bid.bengkel?.name, "Bengkel A")
    }
}
