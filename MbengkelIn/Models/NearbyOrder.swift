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
    var tireCount: Int?
    var photoUrls: [String]?
    var vehicleId: String?
    var vehicleInfo: String?
    var bengkelId: String?
    var rating: Int?
    var review: String?
    var customerCompleted: Bool?
    var providerCompleted: Bool?
    var completionPhotoUrl: String?
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
        case tireCount = "tire_count"
        case photoUrls = "photo_urls"
        case vehicleId = "vehicle_id"
        case vehicleInfo = "vehicle_info"
        case bengkelId = "bengkel_id"
        case rating
        case review
        case customerCompleted = "customer_completed"
        case providerCompleted = "provider_completed"
        case completionPhotoUrl = "completion_photo_url"
        case createdAt = "created_at"
        case distanceM = "distance_m"
    }
}
