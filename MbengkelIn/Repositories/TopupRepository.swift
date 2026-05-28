import Foundation
import Supabase

class TopupRepository {
    func fetchTopups(userId: String) async throws -> [Topup] {
        return try await supabase.from("topups")
            .select()
            .eq("user_id", value: userId)
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    func fetchTopup(orderId: String) async throws -> Topup {
        return try await supabase.from("topups")
            .select()
            .eq("order_id", value: orderId)
            .single()
            .execute()
            .value
    }
}
