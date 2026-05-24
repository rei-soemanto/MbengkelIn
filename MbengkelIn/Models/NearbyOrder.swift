import Foundation

struct NearbyOrder: Codable, Identifiable {
    var id: String
    var customerId: String
    var customerName: String?
    var serviceType: String?
    var description: String?
    var isEmergency: Bool?
    var latitude: Double
    var longitude: Double
    var price: Int?
    var status: String
    var createdAt: String?
    var distanceM: Double?

    enum CodingKeys: String, CodingKey {
        case id
        case customerId = "customer_id"
        case customerName = "customer_name"
        case serviceType = "service_type"
        case description
        case isEmergency = "is_emergency"
        case latitude
        case longitude
        case price
        case status
        case createdAt = "created_at"
        case distanceM = "distance_m"
    }
}
