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

    func fetchTodaysEarnings(bengkelId: String) async throws -> Double {
        let startOfDay = Calendar.current.startOfDay(for: Date())
        let iso = ISO8601DateFormatter().string(from: startOfDay)
        let rows: [TodaysEarningRow] = try await supabase.from("service_requests")
            .select("price")
            .eq("bengkel_id", value: bengkelId)
            .eq("status", value: "Done")
            .gte("completed_at", value: iso)
            .execute()
            .value
        return rows.reduce(0.0) { $0 + Double($1.price ?? 0) }
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

    func submitRating(requestId: String, rating: Int, review: String?) async throws {
        let payload = RatingPayload(rating: rating, review: review)
        try await supabase.from("service_requests")
            .update(payload)
            .eq("id", value: requestId)
            .execute()
    }

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

    // MARK: Watch companion support

    func fetchActiveOrder(customerId: String) async throws -> NearbyOrder? {
        let orders: [NearbyOrder] = try await supabase.from("service_requests")
            .select()
            .eq("customer_id", value: customerId)
            .in("status", values: ["To Do", "On Progress", "Done"])
            .order("created_at", ascending: false)
            .limit(1)
            .execute()
            .value
        return orders.first
    }

    func fetchPendingBids(serviceRequestId: String) async throws -> [Bid] {
        return try await supabase.from("bids")
            .select("*, bengkel:bengkels(*)")
            .eq("service_request_id", value: serviceRequestId)
            .eq("status", value: "Pending")
            .order("price", ascending: true)
            .execute()
            .value
    }

    func acceptBid(serviceRequestId: String, bidId: String, bengkelId: String, price: Int) async throws {
        try await supabase.from("bids")
            .update(BidStatusUpdate(status: "Accepted"))
            .eq("id", value: bidId)
            .execute()
        try await supabase.from("bids")
            .update(BidStatusUpdate(status: "AutoRejected"))
            .eq("service_request_id", value: serviceRequestId)
            .neq("id", value: bidId)
            .execute()
        try await supabase.from("service_requests")
            .update(AcceptOrderPayload(bengkel_id: bengkelId, status: "On Progress", price: price))
            .eq("id", value: serviceRequestId)
            .execute()
    }
}
