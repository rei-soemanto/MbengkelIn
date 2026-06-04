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
    private let authService = AuthService()
    private var realtimeChannel: RealtimeChannelV2?
    private var realtimeReaderTasks: [Task<Void, Never>] = []

    nonisolated init(serviceRequestId: String) {
        self.serviceRequestId = serviceRequestId
    }

    deinit {
        realtimeReaderTasks.forEach { $0.cancel() }
        realtimeReaderTasks.removeAll()
        if let channel = realtimeChannel {
            Task { await supabase.removeChannel(channel) }
        }
    }

    func start() async {
        if let uid = try? await authService.currentUID() {
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
            self.isLocked = !["To Do", "On Progress"].contains(order.status)
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
            filter: .eq("service_request_id", value: serviceRequestId)
        )
        let orderStream = channel.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "service_requests",
            filter: .eq("id", value: serviceRequestId)
        )

        realtimeReaderTasks.append(Task { [weak self] in
            guard let self = self else { return }
            try? await channel.subscribeWithError()

            Task { [weak self] in
                for await _ in messageStream { await self?.loadMessages() }
            }
            Task { [weak self] in
                for await _ in orderStream { await self?.loadLockState() }
            }
        })
    }

    func stopRealtimeSubscription() {
        realtimeReaderTasks.forEach { $0.cancel() }
        realtimeReaderTasks.removeAll()
        if let channel = realtimeChannel {
            Task { await supabase.removeChannel(channel) }
            realtimeChannel = nil
        }
    }

    func sendText() async {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isLocked else { return }
        if await send(content: text, imageUrl: nil) {
            draft = ""
        }
    }

    func sendImage(data: Data) async {
        guard !isLocked else { return }
        isSending = true
        errorMessage = nil
        do {
            let compressed = ImageCompressor.compressed(data)
            let url = try await storageService.uploadChatImage(serviceRequestId: serviceRequestId, data: compressed)
            await send(content: nil, imageUrl: url)
        } catch {
            self.errorMessage = error.localizedDescription
        }
        isSending = false
    }

    @discardableResult
    private func send(content: String?, imageUrl: String?) async -> Bool {
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
            isSending = false
            return true
        } catch {
            self.errorMessage = error.localizedDescription
            isSending = false
            return false
        }
    }
}
