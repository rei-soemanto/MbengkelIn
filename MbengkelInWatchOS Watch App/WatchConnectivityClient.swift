//
//  WatchConnectivityClient.swift
//  MbengkelInWatchOS Watch App
//
//  Created by Rei Soemanto on 29/05/26.
//

import Foundation
import Combine
import WatchConnectivity
import UserNotifications

@MainActor
final class WatchConnectivityClient: NSObject, ObservableObject {
    static let shared = WatchConnectivityClient()

    @Published var state: WatchOrderState = .empty
    @Published var isWorking = false
    @Published var errorMessage: String?

    private var wcSession: WCSession? { WCSession.isSupported() ? WCSession.default : nil }

    private override init() { super.init() }

    func activate() {
        guard let wcSession else { return }
        wcSession.delegate = self
        wcSession.activate()
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func requestState() { send(["command": "requestState"]) }

    func approve(bidId: String) {
        guard let requestId = state.requestId else { return }
        send(["command": "approveBid", "requestId": requestId, "bidId": bidId], expectsReply: true)
    }
    func finishJob() {
        guard let requestId = state.requestId else { return }
        send(["command": "finishJob", "requestId": requestId], expectsReply: true)
    }
    func submitRating(_ rating: Int) {
        guard let requestId = state.requestId else { return }
        send(["command": "submitRating", "requestId": requestId, "rating": rating], expectsReply: true)
    }

    private func send(_ message: [String: Any], expectsReply: Bool = false) {
        guard let wcSession else { return }
        if expectsReply { isWorking = true }
        if wcSession.isReachable {
            wcSession.sendMessage(message, replyHandler: { [weak self] reply in
                Task { @MainActor in self?.handleReply(reply) }
            }, errorHandler: { [weak self] _ in
                Task { @MainActor in
                    self?.isWorking = false
                    self?.wcSession?.transferUserInfo(message) // queue for background delivery
                }
            })
        } else {
            wcSession.transferUserInfo(message)
            if expectsReply { isWorking = false }
        }
    }

    private func handleReply(_ reply: [String: Any]) {
        isWorking = false
        if let error = reply["error"] as? String { errorMessage = error; return }
        if let data = reply["state"] as? Data,
           let decoded = try? JSONDecoder().decode(WatchOrderState.self, from: data) {
            state = decoded
        }
    }

    private func fireLocalNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}

extension WatchConnectivityClient: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in if activationState == .activated { self.requestState() } }
    }
    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        guard let data = applicationContext["state"] as? Data else { return }
        Task { @MainActor in
            self.isWorking = false
            if let decoded = try? JSONDecoder().decode(WatchOrderState.self, from: data) { self.state = decoded }
        }
    }
    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        let title = userInfo["notifTitle"] as? String
        let body = userInfo["notifBody"] as? String
        Task { @MainActor in
            if let title, let body { self.fireLocalNotification(title: title, body: body) }
        }
    }
}
