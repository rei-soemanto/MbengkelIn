import Foundation

// Order Repository DTOs
struct ServiceRequestPayload: Encodable {
    let customer_id: String
    let service_type: ServiceType
    let description: String
    let latitude: Double
    let longitude: Double
    let price: Int
    let is_emergency: Bool
    let status: String
    let tire_count: Int
    let photo_urls: [String]?
}

struct CreatedServiceRequest: Decodable {
    let id: String
}

// Customer Bidding DTOs
struct BengkelUpdate: Encodable {
    let bengkel_id: String
    let status: String
}

struct AcceptOrderPayload: Encodable {
    let bengkel_id: String
    let status: String
    let price: Int
}

struct BidStatusUpdate: Encodable {
    let status: String
}

struct StartSearchPayload: Encodable {
    let price: Int
}

// Mechanic Bidding DTOs
struct OrdersRequest: Encodable {
    let action: String
    let latitude: Double
    let longitude: Double
    let radiusMeters: Double
}

struct OrdersResponse: Decodable {
    let orders: [NearbyOrder]
}

struct PlaceBidRequest: Encodable {
    let action: String
    let serviceRequestId: String
    let bengkelId: String
    let price: Int
    let notes: String?
}

struct PlaceBidResponse: Decodable {
    let bid: Bid
}
