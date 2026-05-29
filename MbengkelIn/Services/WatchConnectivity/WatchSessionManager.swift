//
//  WatchSessionManager.swift
//  MbengkelIn
//
//  Created by Rei Soemanto on 29/05/26.
//

import Foundation
import Combine
import WatchConnectivity
import Supabase

// Phone-side coordinator: observes the logged-in customer's active order via
// Supabase Realtime, pushes a WatchOrderState snapshot to the paired watch,
// forwards local notifications, and executes the watch's approve/finish/rate
// commands against the existing repositories.
//
// Implementation is split across this folder for the 100-line file budget:
//   • WatchSessionManager.swift        — state stored props, observe, push
//   • WatchSessionManager+Commands.swift — command handling from the watch
//   • WatchSessionManager+Delegate.swift — WCSessionDelegate conformance
@MainActor
final class WatchSessionManager: NSObject, ObservableObject {
    static let shared = WatchSessionManager()

    let orderRepository = OrderRepository()
    let userRepository = UserRepository()

    var customerId: String?
    var requestChannel: RealtimeChannelV2?
    var bidChannel: RealtimeChannelV2?
    var bidChannelRequestId: String?
    var lastState: WatchOrderState = .empty

    var wcSession: WCSession? { WCSession.isSupported() ? WCSession.default : nil }

    private override init() { super.init() }

    func activate() {
        guard let wcSession else { return }
        wcSession.delegate = self
        wcSession.activate()
    }

    // MARK: Observe

    func startObserving(customerId: String) {
        if self.customerId == customerId, requestChannel != nil { return }
        self.customerId = customerId
        Task {
            await self.subscribeRequestChannel()
            await self.rebuildState()
        }
    }

    func stop() {
        customerId = nil
        bidChannelRequestId = nil
        if let requestChannel { Task { await supabase.removeChannel(requestChannel) } }
        if let bidChannel { Task { await supabase.removeChannel(bidChannel) } }
        requestChannel = nil
        bidChannel = nil
        lastState = .empty
        pushState(lastState)
    }

    func subscribeRequestChannel() async {
        guard let customerId, requestChannel == nil else { return }
        let channel = supabase.channel("watch-requests-\(customerId)")
        requestChannel = channel
        let stream = channel.postgresChange(
            AnyAction.self, schema: "public", table: "service_requests",
            filter: "customer_id=eq.\(customerId)"
        )
        Task { [weak self] in
            await channel.subscribe()
            for await _ in stream { await self?.rebuildState() }
        }
    }

    func subscribeBidChannel(requestId: String) async {
        if bidChannelRequestId == requestId, bidChannel != nil { return }
        if let bidChannel { await supabase.removeChannel(bidChannel) }
        let channel = supabase.channel("watch-bids-\(requestId)")
        bidChannel = channel
        bidChannelRequestId = requestId
        let stream = channel.postgresChange(
            AnyAction.self, schema: "public", table: "bids",
            filter: "service_request_id=eq.\(requestId)"
        )
        Task { [weak self] in
            await channel.subscribe()
            for await _ in stream { await self?.rebuildState() }
        }
    }

    // MARK: Push to watch

    func pushState(_ state: WatchOrderState) {
        guard let wcSession, wcSession.activationState == .activated else { return }
        guard let data = try? JSONEncoder().encode(state) else { return }
        try? wcSession.updateApplicationContext(["state": data])
    }

    func forwardNotification(title: String, body: String) {
        guard let wcSession, wcSession.activationState == .activated else { return }
        wcSession.transferUserInfo(["notifTitle": title, "notifBody": body])
    }
}
