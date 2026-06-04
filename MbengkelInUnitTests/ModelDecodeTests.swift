import Testing
import Foundation
@testable import MbengkelIn

@Suite("ModelDecode")
@MainActor struct ModelDecodeTests {
    private let decoder = JSONDecoder()

    @Test func vehicleDecode() throws {
        let json = #"""
        {"id":"v1","customer_id":"c1","manufacturer":"Honda","model":"Beat",
        "year":2021,"license_plate":"B 1234 ABC","color":"Hitam"}
        """#
        let vehicle = try decoder.decode(Vehicle.self, from: Data(json.utf8))
        #expect(vehicle.id == "v1")
        #expect(vehicle.customerId == "c1")
        #expect(vehicle.manufacturer == "Honda")
        #expect(vehicle.model == "Beat")
        #expect(vehicle.year == 2021)
        #expect(vehicle.licensePlate == "B 1234 ABC")
        #expect(vehicle.color == "Hitam")
    }

    @Test func orderLocationDecode() throws {
        let json = #"""
        {"service_request_id":"r1","provider_uid":"p1","latitude":-7.28,
        "longitude":112.63,"updated_at":"2026-06-03T10:00:00Z"}
        """#
        let location = try decoder.decode(OrderLocation.self, from: Data(json.utf8))
        #expect(location.serviceRequestId == "r1")
        #expect(location.providerUid == "p1")
        #expect(location.latitude == -7.28)
        #expect(location.longitude == 112.63)
        #expect(location.updatedAt == "2026-06-03T10:00:00Z")
        #expect(location.id == "r1")
    }

    @Test func chatMessageFull() throws {
        let json = #"""
        {"id":"m1","service_request_id":"r1","sender_id":"s1",
        "content":"Halo","image_url":"https://x/y.jpg","created_at":"2026-06-03T10:00:00Z"}
        """#
        let message = try decoder.decode(ChatMessage.self, from: Data(json.utf8))
        #expect(message.id == "m1")
        #expect(message.serviceRequestId == "r1")
        #expect(message.senderId == "s1")
        #expect(message.content == "Halo")
        #expect(message.imageUrl == "https://x/y.jpg")
        #expect(message.createdAt == "2026-06-03T10:00:00Z")
    }

    @Test func chatMessageWithoutContentAndImage() throws {
        let json = #"{"id":"m2","service_request_id":"r1","sender_id":"s1"}"#
        let message = try decoder.decode(ChatMessage.self, from: Data(json.utf8))
        #expect(message.content == nil)
        #expect(message.imageUrl == nil)
        #expect(message.createdAt == nil)
        #expect(message.senderId == "s1")
    }
}
