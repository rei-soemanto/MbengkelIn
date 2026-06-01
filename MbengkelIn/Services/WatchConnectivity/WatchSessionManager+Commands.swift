//
//  WatchSessionManager+Commands.swift
//  MbengkelIn
//
//  Created by Rei Soemanto on 29/05/26.
//

import Foundation
import Supabase

// State assembly + execution of the watch's approve/finish/rate commands.
@MainActor
extension WatchSessionManager {

    // MARK: Build + push state

    func rebuildState() async {
        guard let customerId else { lastState = .empty; pushState(lastState); return }
        do {
            guard let order = try await orderRepository.fetchActiveOrder(customerId: customerId) else {
                lastState = .empty; pushState(lastState); return
            }
            let status = order.status
            let rating = order.rating ?? 0
            let isActive = status == "To Do" || status == "On Progress" || (status == "Done" && rating == 0)
            guard isActive else { lastState = .empty; pushState(lastState); return }

            await subscribeBidChannel(requestId: order.id)

            var stage = "finding"
            if status == "On Progress" { stage = "inProgress" }
            else if status == "Done" { stage = "finished" }

            var offers: [WatchBidOffer] = []
            var bengkelName: String?
            var agreedPrice: Int? = order.price

            if status == "To Do" {
                let bids = try await orderRepository.fetchPendingBids(serviceRequestId: order.id)
                offers = bids.map {
                    WatchBidOffer(bidId: $0.id, bengkelName: $0.bengkel?.name ?? "Bengkel",
                                  price: $0.price, rating: $0.bengkel?.averageRating)
                }
            } else if let accepted = try? await orderRepository.fetchAcceptedBid(serviceRequestId: order.id) {
                bengkelName = accepted.bengkel?.name
                agreedPrice = accepted.price
            }

            let state = WatchOrderState(
                hasActiveOrder: true, stage: stage, serviceType: order.serviceType,
                bengkelName: bengkelName, agreedPrice: agreedPrice,
                mySideCompleted: order.customerCompleted ?? false,
                alreadyRated: rating > 0, requestId: order.id, offers: offers
            )
            lastState = state
            pushState(state)
        } catch {
            // Keep last good state on transient error.
        }
    }

    // MARK: Commands from watch

    func handleCommand(_ message: [String: Any], reply: @escaping ([String: Any]) -> Void) async {
        let command = message["command"] as? String ?? ""
        do {
            switch command {
            case "requestState":
                if customerId == nil {
                    customerId = try? await supabase.auth.session.user.id.uuidString.lowercased()
                    if customerId != nil { await subscribeRequestChannel() }
                }
                await rebuildState()
                if let data = try? JSONEncoder().encode(lastState) { reply(["state": data]) }
                else { reply(["ok": true]) }
            case "approveBid":
                try await approveBid(message)
                await rebuildState()
                reply(["ok": true])
            case "finishJob":
                guard let requestId = message["requestId"] as? String else { reply(["error": "Permintaan tidak valid."]); return }
                _ = try await orderRepository.markOrderCompleted(requestId: requestId)
                await rebuildState()
                reply(["ok": true])
            case "submitRating":
                guard let requestId = message["requestId"] as? String, let rating = message["rating"] as? Int else { reply(["error": "Penilaian tidak valid."]); return }
                try await orderRepository.submitRating(requestId: requestId, rating: rating, review: nil)
                await rebuildState()
                reply(["ok": true])
            default:
                reply(["error": "Perintah tidak dikenal."])
            }
        } catch {
            reply(["error": error.localizedDescription])
        }
    }

    func approveBid(_ message: [String: Any]) async throws {
        guard let bidId = message["bidId"] as? String else {
            throw NSError(domain: "watch", code: 1, userInfo: [NSLocalizedDescriptionKey: "Argumen tidak lengkap."])
        }
        // Server-authoritative accept_bid RPC validates owner, open status, and
        // balance in one transaction; any failure (e.g. "Saldo tidak cukup") is
        // surfaced through the thrown error's localizedDescription.
        _ = try await orderRepository.acceptBid(bidId: bidId)
    }
}
