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

struct OpenDisputeParams: Encodable {
    let p_request_id: String
    let p_reason: String
    let p_proof_url: String?
}

struct TodaysEarningRow: Decodable {
    let price: Int?
}

// Customer Bidding DTOs
struct BidStatusUpdate: Encodable {
    let status: String
}

struct AcceptBidParams: Encodable {
    let p_bid_id: String
}

// Params for the cancel_order RPC (bidding-phase give-up; To Do → Cancelled).
struct CancelOrderParams: Encodable {
    let p_request_id: String
}

struct StartSearchPayload: Encodable {
    let price: Int
}

// Customer rating of a completed order, via the rate_order RPC. The RPC's UPDATE
// of the `rating` column fires the trigger that recomputes the bengkel's
// average_rating / total_reviews. Enforces customer-owned + Done + not-yet-rated.
struct RateOrderParams: Encodable {
    let p_request_id: String
    let p_rating: Int
    let p_review: String?
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

struct CustomerLocationPayload: Encodable {
    let service_request_id: String
    let customer_id: String
    let latitude: Double
    let longitude: Double
}

// Behavior report payload — inserted by a party to the order into
// behavior_reports (RLS enforces reporter_id = auth.uid()).
struct BehaviorReportPayload: Encodable {
    let service_request_id: String
    let reporter_id: String
    let reason: String
}
