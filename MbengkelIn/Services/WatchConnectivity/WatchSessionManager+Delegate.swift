//
//  WatchSessionManager+Delegate.swift
//  MbengkelIn
//
//  Created by Rei Soemanto on 29/05/26.
//

import Foundation
import WatchConnectivity

// WCSessionDelegate is delivered on a non-main serial queue, so every callback
// hops to the @MainActor singleton via Task { @MainActor in } (Swift 6 safe).
extension WatchSessionManager: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in if activationState == .activated { self.pushState(self.lastState) } }
    }
    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        Task { @MainActor in await self.handleCommand(message, reply: replyHandler) }
    }
    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        Task { @MainActor in await self.handleCommand(message) { _ in } }
    }
    // iOS-only required stubs:
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}
    nonisolated func sessionDidDeactivate(_ session: WCSession) { session.activate() }
}
