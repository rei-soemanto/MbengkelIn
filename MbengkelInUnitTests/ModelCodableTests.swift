import Testing
import Foundation
@testable import MbengkelIn

@Suite("ModelCodable")
@MainActor struct ModelCodableTests {
    private let decoder = JSONDecoder()

    @Test func userWithHeldBalance() throws {
        let json = #"{"id":"u1","name":"Budi","balance":100000,"held_balance":30000,"role":"USER"}"#
        let user = try decoder.decode(User.self, from: Data(json.utf8))
        #expect(user.balance == 100000)
        #expect(user.heldBalance == 30000)
        #expect(user.availableBalance == 70000)
        #expect(user.email == nil)
        #expect(user.phoneNumber == nil)
    }

    @Test func userWithoutHeldBalance() throws {
        let json = #"{"id":"u2","name":"Ani","balance":50000,"role":"USER"}"#
        let user = try decoder.decode(User.self, from: Data(json.utf8))
        #expect(user.heldBalance == nil)
        #expect(user.availableBalance == user.balance)
    }

    @Test func nearbyOrderFull() throws {
        let json = #"""
        {"id":"r1","customer_id":"c1","service_type":"Ban Gembos","latitude":-7.28,
        "longitude":112.63,"status":"To Do","tire_count":2,"photo_urls":["a","b"],
        "customer_completed":true,"vehicle_id":"v1","vehicle_info":"Honda Beat \u2022 B 1 ABC"}
        """#
        let order = try decoder.decode(NearbyOrder.self, from: Data(json.utf8))
        #expect(order.serviceType == "Ban Gembos")
        #expect(order.tireCount == 2)
        #expect(order.photoUrls?.count == 2)
        #expect(order.vehicleId == "v1")
        #expect(order.vehicleInfo == "Honda Beat • B 1 ABC")
        #expect(order.customerCompleted == true)
    }

    @Test func nearbyOrderMinimal() throws {
        let json = #"{"id":"r2","customer_id":"c2","latitude":0,"longitude":0,"status":"To Do"}"#
        let order = try decoder.decode(NearbyOrder.self, from: Data(json.utf8))
        #expect(order.serviceType == nil)
        #expect(order.tireCount == nil)
        #expect(order.photoUrls == nil)
        #expect(order.vehicleId == nil)
        #expect(order.price == nil)
    }

    @Test func bengkelDecode() throws {
        let json = #"""
        {"id":"b1","provider_uid":"p1","name":"Bengkel A","address":"Jl X",
        "latitude":-7.2,"longitude":112.6,"status":"Verified","offered_services":[],
        "average_rating":4.5,"total_reviews":10}
        """#
        let bengkel = try decoder.decode(Bengkel.self, from: Data(json.utf8))
        #expect(bengkel.averageRating == 4.5)
        #expect(bengkel.totalReviews == 10)
        #expect(bengkel.offeredServices.isEmpty)
        #expect(bengkel.providerUid == "p1")
    }

    @Test func bidWithNestedBengkel() throws {
        let json = #"""
        {"id":"bid1","service_request_id":"r1","provider_uid":"p1","bengkel_id":"b1",
        "price":75000,"status":"Pending","bengkel":{"id":"b1","provider_uid":"p1",
        "name":"Bengkel A","address":"Jl X","latitude":-7.2,"longitude":112.6,
        "status":"Verified","offered_services":[],"average_rating":4.0,"total_reviews":3}}
        """#
        let bid = try decoder.decode(Bid.self, from: Data(json.utf8))
        #expect(bid.price == 75000)
        #expect(bid.bengkel?.name == "Bengkel A")
    }
}
