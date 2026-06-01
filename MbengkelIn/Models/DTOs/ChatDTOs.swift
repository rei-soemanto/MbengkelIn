import Foundation

struct ChatMessagePayload: Encodable {
    let service_request_id: String
    let sender_id: String
    let content: String?
    let image_url: String?
}

struct MarkCompletedParams: Encodable {
    let p_request_id: String
    let p_completion_photo_url: String?
}
