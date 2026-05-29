//
//  HistoryViewModel.swift
//  MbengkelIn
//
//  Created by Bryan Fernando Dinata on 28/05/26.
//

import SwiftUI
import CoreLocation
import Supabase
import Combine

@MainActor
class HistoryViewModel: ObservableObject {
    @Published var orders: [NearbyOrder] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    @Published var detailOrder: NearbyOrder?
    @Published var biddingOrder: NearbyOrder?
    @Published var trackingBid: Bid?
    @Published var trackingCoordinate: CLLocationCoordinate2D?

    private let authService = AuthService()
    private let orderRepository = OrderRepository()

    func loadOrders() async {
        isLoading = true
        errorMessage = nil
        guard let session = try? await authService.getCurrentSession() else {
            isLoading = false
            return
        }
        let uid = session.user.id.uuidString.lowercased()
        do {
            let fetched = try await orderRepository.fetchOrders(customerId: uid)
            self.orders = fetched.sorted(by: Self.isOrderedBefore)
        } catch {
            self.errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    @MainActor
    func select(_ order: NearbyOrder) async {
        if order.status == "On Progress" {
            await openTracking(order)
        } else if order.status == "To Do" {
            self.biddingOrder = order
        } else {
            self.detailOrder = order
        }
    }

    private func openTracking(_ order: NearbyOrder) async {
        do {
            if let bid = try await orderRepository.fetchAcceptedBid(serviceRequestId: order.id) {
                self.trackingCoordinate = CLLocationCoordinate2D(
                    latitude: order.latitude,
                    longitude: order.longitude
                )
                self.trackingBid = bid
            } else {
                self.detailOrder = order
            }
        } catch {
            self.errorMessage = error.localizedDescription
        }
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
