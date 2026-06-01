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
    let vehicle_id: String?
    let vehicle_info: String?
}

struct CreatedServiceRequest: Decodable {
    let id: String
}

struct TodaysEarningRow: Decodable {
    let price: Int?
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

struct OrderStatusUpdate: Encodable {
    let status: String
}

struct StartSearchPayload: Encodable {
    let price: Int
}

// Customer rating of a completed order. Writing `rating` fires a Postgres
// trigger that recomputes the bengkel's average_rating / total_reviews.
struct RatingPayload: Encodable {
    let rating: Int
    let review: String?
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

// Upsert payload for the assigned bengkel's live location while an order is
// in progress (order_locations table).
struct OrderLocationPayload: Encodable {
    let service_request_id: String
    let provider_uid: String
    let latitude: Double
    let longitude: Double
}
