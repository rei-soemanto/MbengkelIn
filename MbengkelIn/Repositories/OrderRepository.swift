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

    func fetchOrders(customerId: String) async throws -> [NearbyOrder] {
        return try await supabase.from("service_requests")
            .select()
            .eq("customer_id", value: customerId)
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    func fetchBengkelOrders(bengkelId: String) async throws -> [NearbyOrder] {
        return try await supabase.from("service_requests")
            .select()
            .eq("bengkel_id", value: bengkelId)
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    func fetchAcceptedBid(serviceRequestId: String) async throws -> Bid? {
        let bids: [Bid] = try await supabase.from("bids")
            .select("*, bengkel:bengkels(*)")
            .eq("service_request_id", value: serviceRequestId)
            .eq("status", value: "Accepted")
            .limit(1)
            .execute()
            .value
        return bids.first
    }
}
