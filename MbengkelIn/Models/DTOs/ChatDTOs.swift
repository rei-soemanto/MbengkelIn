import Foundation

// ChatRepository insert payload
struct ChatMessagePayload: Encodable {
    let service_request_id: String
    let sender_id: String
    let content: String?
    let image_url: String?
}

// OrderRepository mark_order_completed RPC params
struct MarkCompletedParams: Encodable {
    let p_request_id: String
}
