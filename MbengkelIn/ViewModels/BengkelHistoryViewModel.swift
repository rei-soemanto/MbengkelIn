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
class BengkelHistoryViewModel: ObservableObject {
    @Published var orders: [NearbyOrder] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var detailOrder: NearbyOrder?

    private let bengkelRepository = BengkelRepository()
    private let orderRepository = OrderRepository()

    func loadOrders() async {
        isLoading = true
        errorMessage = nil
        do {
            let uid = try await supabase.auth.session.user.id.uuidString.lowercased()
            let bengkel = try await bengkelRepository.fetchBengkel(providerUid: uid)
            guard let bengkelId = bengkel.id else {
                isLoading = false
                return
            }
            let fetched = try await orderRepository.fetchBengkelOrders(bengkelId: bengkelId)
            self.orders = fetched.sorted(by: Self.isOrderedBefore)
        } catch {
            self.errorMessage = error.localizedDescription
        }
        isLoading = false
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
