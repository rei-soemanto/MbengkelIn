import Foundation
import Supabase

class ChatRepository {
    func fetchMessages(serviceRequestId: String) async throws -> [ChatMessage] {
        return try await supabase.from("chat_messages")
            .select()
            .eq("service_request_id", value: serviceRequestId)
            .order("created_at", ascending: true)
            .execute()
            .value
    }

    func sendMessage(_ payload: ChatMessagePayload) async throws {
        try await supabase.from("chat_messages")
            .insert(payload)
            .execute()
    }
}
