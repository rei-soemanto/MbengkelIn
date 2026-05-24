import Foundation

struct Bid: Codable, Identifiable {
    var id: String
    var serviceRequestId: String
    var providerUid: String
    var bengkelId: String
    var price: Int
    var notes: String?
    var status: String
    var createdAt: String?
    var bengkel: Bengkel?

    enum CodingKeys: String, CodingKey {
        case id
        case serviceRequestId = "service_request_id"
        case providerUid = "provider_uid"
        case bengkelId = "bengkel_id"
        case price
        case notes
        case status
        case createdAt = "created_at"
        case bengkel
    }
}
