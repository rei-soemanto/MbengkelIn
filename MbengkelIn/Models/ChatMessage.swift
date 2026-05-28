import Foundation

struct ChatMessage: Codable, Identifiable {
    var id: String
    var serviceRequestId: String
    var senderId: String
    var content: String?
    var imageUrl: String?
    var createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case serviceRequestId = "service_request_id"
        case senderId = "sender_id"
        case content
        case imageUrl = "image_url"
        case createdAt = "created_at"
    }
}
