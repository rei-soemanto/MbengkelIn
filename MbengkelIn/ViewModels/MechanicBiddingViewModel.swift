import SwiftUI
import Combine
import Combine
import Supabase

@MainActor
class MechanicBiddingViewModel: ObservableObject {
    @Published var orders: [NearbyOrder] = []
    @Published var myBengkel: Bengkel?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?

    private struct OrdersRequest: Encodable {
        let action: String
        let latitude: Double
        let longitude: Double
        let radiusMeters: Double
    }

    private struct OrdersResponse: Decodable {
        let orders: [NearbyOrder]
    }

    private struct PlaceBidRequest: Encodable {
        let action: String
        let serviceRequestId: String
        let bengkelId: String
        let price: Int
        let notes: String?
    }

    private struct PlaceBidResponse: Decodable {
        let bid: Bid
    }

    func start() async {
        isLoading = true
        errorMessage = nil
        do {
            let uid = try await supabase.auth.session.user.id.uuidString.lowercased()
            let fetched: Bengkel = try await supabase.from("bengkels")
                .select()
                .eq("provider_uid", value: uid)
                .limit(1)
                .single()
                .execute()
                .value
            self.myBengkel = fetched
        } catch {
            self.errorMessage = error.localizedDescription
            isLoading = false
            return
        }
        await loadOrders()
        isLoading = false
    }

    func loadOrders() async {
        guard let bengkel = myBengkel else { return }
        errorMessage = nil
        do {
            let body = OrdersRequest(
                action: "ordersForMechanic",
                latitude: bengkel.latitude,
                longitude: bengkel.longitude,
                radiusMeters: 5000
            )
            let response: OrdersResponse = try await supabase.functions.invoke(
                "bidding",
                options: FunctionInvokeOptions(body: body)
            )
            self.orders = response.orders
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }

    func placeBid(order: NearbyOrder, price: Int, notes: String) async {
        guard let bengkel = myBengkel, let bengkelId = bengkel.id else { return }
        isLoading = true
        errorMessage = nil
        successMessage = nil
        do {
            let body = PlaceBidRequest(
                action: "placeBid",
                serviceRequestId: order.id,
                bengkelId: bengkelId,
                price: price,
                notes: notes.isEmpty ? nil : notes
            )
            let _: PlaceBidResponse = try await supabase.functions.invoke(
                "bidding",
                options: FunctionInvokeOptions(body: body)
            )
            self.successMessage = "Tawaran terkirim."
            await loadOrders()
        } catch {
            self.errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
