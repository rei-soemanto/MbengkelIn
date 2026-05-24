import Foundation
import Supabase

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
