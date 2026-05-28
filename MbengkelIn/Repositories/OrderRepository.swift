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

    func fetchOrder(id: String) async throws -> NearbyOrder {
        return try await supabase.from("service_requests")
            .select()
            .eq("id", value: id)
            .single()
            .execute()
            .value
    }

    func deleteOrder(id: String) async throws {
        try await supabase.from("service_requests")
            .delete()
            .eq("id", value: id)
            .execute()
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

    // Marks the caller's side complete; status flips to "Done" only when both sides confirm.
    @discardableResult
    func markOrderCompleted(requestId: String) async throws -> NearbyOrder {
        return try await supabase.rpc(
            "mark_order_completed",
            params: MarkCompletedParams(p_request_id: requestId)
        )
        .single()
        .execute()
        .value
    }
}
