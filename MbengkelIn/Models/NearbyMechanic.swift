import Foundation

struct NearbyMechanic: Codable, Identifiable {
    var id: String
    var providerUid: String
    var name: String
    var address: String
    var latitude: Double
    var longitude: Double
    var averageRating: Double
    var totalReviews: Int
    var offeredServices: [BengkelService]?
    var distanceM: Double

    enum CodingKeys: String, CodingKey {
        case id
        case providerUid = "provider_uid"
        case name
        case address
        case latitude
        case longitude
        case averageRating = "average_rating"
        case totalReviews = "total_reviews"
        case offeredServices = "offered_services"
        case distanceM = "distance_m"
    }
}
