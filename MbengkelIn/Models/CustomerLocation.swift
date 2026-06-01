import Foundation

// Live location of the customer for an in-progress order (customer_locations table).
struct CustomerLocation: Codable, Identifiable {
    var serviceRequestId: String
    var customerId: String?
    var latitude: Double
    var longitude: Double
    var updatedAt: String?

    var id: String { serviceRequestId }

    enum CodingKeys: String, CodingKey {
        case serviceRequestId = "service_request_id"
        case customerId = "customer_id"
        case latitude
        case longitude
        case updatedAt = "updated_at"
    }
}
