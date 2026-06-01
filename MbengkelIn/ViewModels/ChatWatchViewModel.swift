//
//  ChatWatchViewModel.swift
//  MbengkelIn
//
//  Created by Bryan Fernando Dinata on 29/05/26.
//

import SwiftUI
import Combine
import Supabase

// Watches a single order's chat in the background — while the user is on the
// tracking/route screen rather than inside ChatView — to surface an unread
// badge and fire a local notification for each incoming message from the other
// party. Uses a true Realtime subscription (no polling).
@MainActor
final class ChatWatchViewModel: ObservableObject {
    @Published var unreadCount: Int = 0

    private let serviceRequestId: String
    private let counterpartName: String
    private let cursor: ChatReadCursor
    private var currentUserId: String = ""

    private let chatRepository = ChatRepository()
    private let notificationService = NotificationService()
    private let authService = AuthService()
    private var channel: RealtimeChannelV2?
    private var realtimeReaderTasks: [Task<Void, Never>] = []

    private var notifiedIds: Set<String> = []
    private var didLoadOnce = false

    nonisolated init(serviceRequestId: String, counterpartName: String) {
        self.serviceRequestId = serviceRequestId
        self.counterpartName = counterpartName
        self.cursor = ChatReadCursor(serviceRequestId: serviceRequestId)
    }

    deinit {
        realtimeReaderTasks.forEach { $0.cancel() }
        realtimeReaderTasks.removeAll()
        if let channel = channel {
            let client = supabase
            Task { await client.removeChannel(channel) }
        }
    }

    func start() async {
        notificationService.requestAuthorization()
        if let uid = try? await authService.currentUID() {
            self.currentUserId = uid
        }
        await reload()
        subscribe()
    }

    func stop() {
        realtimeReaderTasks.forEach { $0.cancel() }
        realtimeReaderTasks.removeAll()
        if let channel = channel {
            Task { await supabase.removeChannel(channel) }
            self.channel = nil
        }
    }

    // Called when the user opens this conversation — clears the badge and moves
    // the read cursor to now.
    func markAllRead() {
        cursor.markRead()
        unreadCount = 0
    }

    private func subscribe() {
        stop()
        let channel = supabase.channel("chat-watch-\(serviceRequestId)")
        self.channel = channel

        let stream = channel.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "chat_messages",
            filter: "service_request_id=eq.\(serviceRequestId)"
        )

        realtimeReaderTasks.append(Task { [weak self] in
            await channel.subscribe()
            for await _ in stream { await self?.reload() }
        })
    }

    private func reload() async {
        guard let messages = try? await chatRepository.fetchMessages(serviceRequestId: serviceRequestId) else { return }
        let incoming = messages.filter { $0.senderId != currentUserId }

        // Don't notify or count the conversation the user is actively reading.
        let isViewing = ChatPresence.shared.activeServiceRequestId == serviceRequestId

        // First load only seeds the seen-set so pre-existing messages don't
        // trigger a burst of notifications.
        if didLoadOnce && !isViewing {
            for message in incoming where !notifiedIds.contains(message.id) {
                notificationService.notifyNewOrder(
                    title: counterpartName,
                    body: notificationBody(for: message)
                )
            }
        }
        notifiedIds = Set(incoming.map { $0.id })
        didLoadOnce = true

        if isViewing {
            cursor.markRead()
            unreadCount = 0
        } else {
            unreadCount = cursor.unreadCount(in: incoming)
        }
    }

    private func notificationBody(for message: ChatMessage) -> String {
        if let content = message.content, !content.isEmpty { return content }
        return "Mengirim sebuah gambar"
    }
}
