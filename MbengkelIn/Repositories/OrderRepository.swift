import Foundation
import Supabase

struct ServiceRequestPayload: Encodable {
    let customer_id: String
    let description: String
    let latitude: Double
    let longitude: Double
    let price: Int
    let is_emergency: Bool
    let status: String
}

struct CreatedServiceRequest: Decodable {
    let id: String
}

class OrderRepository {
    func createOrder(payload: ServiceRequestPayload) async throws -> CreatedServiceRequest {
        return try await supabase.from("service_requests")
            .insert(payload)
            .select("id")
            .single()
            .execute()
            .value
    }
}
