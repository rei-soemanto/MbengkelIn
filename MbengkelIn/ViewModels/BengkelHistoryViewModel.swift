//
//  BengkelHistoryViewModel.swift
//  MbengkelIn
//
//  Created by Bryan Fernando Dinata on 28/05/26.
//

import SwiftUI
import Combine
import Supabase

@MainActor
class BengkelHistoryViewModel: ObservableObject, Sendable {
    @Published var orders: [NearbyOrder] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var detailOrder: NearbyOrder?

    private let bengkelRepository = BengkelRepository()
    private let orderRepository = OrderRepository()
    private let authService = AuthService()
    private var channel: RealtimeChannelV2?
    private var bengkelId: String?
    private var realtimeReaderTasks: [Task<Void, Never>] = []

    deinit {
        realtimeReaderTasks.forEach { $0.cancel() }
        realtimeReaderTasks.removeAll()
        if let channel = channel {
            let client = supabase
            Task { await client.removeChannel(channel) }
        }
    }

    func loadOrders() async {
        isLoading = true
        errorMessage = nil
        do {
            let uid = try await authService.currentUID()
            let bengkel = try await bengkelRepository.fetchBengkel(providerUid: uid)
            guard let bengkelId = bengkel.id else {
                isLoading = false
                return
            }
            self.bengkelId = bengkelId
            let fetched = try await orderRepository.fetchBengkelOrders(bengkelId: bengkelId)
            self.orders = fetched.sorted(by: Self.isOrderedBefore)
            startRealtimeIfNeeded()
        } catch {
            self.errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func startRealtimeIfNeeded() {
        guard channel == nil, let bengkelId else { return }
        let channel = supabase.channel("bengkel-history-\(bengkelId)")
        self.channel = channel
        let stream = channel.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "service_requests",
            filter: "bengkel_id=eq.\(bengkelId)"
        )
        realtimeReaderTasks.append(Task { [weak self] in
            await channel.subscribe()
            for await _ in stream {
                await self?.reload()
            }
        })
    }

    private func reload() async {
        guard let bengkelId else { return }
        if let fetched = try? await orderRepository.fetchBengkelOrders(bengkelId: bengkelId) {
            self.orders = fetched.sorted(by: Self.isOrderedBefore)
        }
    }

    func select(_ order: NearbyOrder) {
        self.detailOrder = order
    }

    private static func isOrderedBefore(_ lhs: NearbyOrder, _ rhs: NearbyOrder) -> Bool {
        let lp = priority(lhs.status)
        let rp = priority(rhs.status)
        if lp != rp { return lp < rp }
        return (lhs.createdAt ?? "") > (rhs.createdAt ?? "")
    }

    private static func priority(_ status: String) -> Int {
        switch status {
        case "On Progress": return 0
        case "To Do": return 1
        default: return 2
        }
    }
}
