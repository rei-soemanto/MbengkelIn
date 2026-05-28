import SwiftUI
import Combine
import Supabase

@MainActor
class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var draft: String = ""
    @Published var isSending = false
    @Published var isLocked = false
    @Published var errorMessage: String?

    let serviceRequestId: String
    private(set) var currentUserId: String = ""

    private let chatRepository = ChatRepository()
    private let orderRepository = OrderRepository()
    private let storageService = StorageService()
    private var realtimeChannel: RealtimeChannelV2?

    nonisolated init(serviceRequestId: String) {
        self.serviceRequestId = serviceRequestId
    }

    deinit {
        if let channel = realtimeChannel {
            let client = supabase
            Task { await client.removeChannel(channel) }
        }
    }

    func start() async {
        if let uid = try? await supabase.auth.session.user.id.uuidString.lowercased() {
            self.currentUserId = uid
        }
        await loadMessages()
        await loadLockState()
        startRealtimeSubscription()
    }

    func loadMessages() async {
        do {
            self.messages = try await chatRepository.fetchMessages(serviceRequestId: serviceRequestId)
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }

    func loadLockState() async {
        do {
            let order = try await orderRepository.fetchOrder(id: serviceRequestId)
            self.isLocked = !(order.status == "To Do" || order.status == "On Progress")
        } catch {
            // If we can't read it, fail safe by not locking the UI.
        }
    }

    func startRealtimeSubscription() {
        stopRealtimeSubscription()
        let channel = supabase.channel("chat-\(serviceRequestId)")
        self.realtimeChannel = channel

        let messageStream = channel.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "chat_messages",
            filter: "service_request_id=eq.\(serviceRequestId)"
        )
        let orderStream = channel.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "service_requests",
            filter: "id=eq.\(serviceRequestId)"
        )

        Task { [weak self] in
            guard let self = self else { return }
            await channel.subscribe()

            Task { [weak self] in
                for await _ in messageStream { await self?.loadMessages() }
            }
            Task { [weak self] in
                for await _ in orderStream { await self?.loadLockState() }
            }
        }
    }

    func stopRealtimeSubscription() {
        if let channel = realtimeChannel {
            Task { await supabase.removeChannel(channel) }
            realtimeChannel = nil
        }
    }

    func sendText() async {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isLocked else { return }
        draft = ""
        await send(content: text, imageUrl: nil)
    }

    func sendImage(data: Data) async {
        guard !isLocked else { return }
        isSending = true
        errorMessage = nil
        do {
            let url = try await storageService.uploadChatImage(serviceRequestId: serviceRequestId, data: data)
            await send(content: nil, imageUrl: url)
        } catch {
            self.errorMessage = error.localizedDescription
        }
        isSending = false
    }

    private func send(content: String?, imageUrl: String?) async {
        isSending = true
        errorMessage = nil
        do {
            let payload = ChatMessagePayload(
                service_request_id: serviceRequestId,
                sender_id: currentUserId,
                content: content,
                image_url: imageUrl
            )
            try await chatRepository.sendMessage(payload)
            await loadMessages()
        } catch {
            self.errorMessage = error.localizedDescription
        }
        isSending = false
    }
}
