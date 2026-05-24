import SwiftUI
import Combine
import Supabase

@MainActor
class MechanicBiddingViewModel: ObservableObject {
    @Published var orders: [NearbyOrder] = []
    @Published var myBengkel: Bengkel?
    @Published var myPendingBids: [Bid] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?

    private var realtimeChannel: RealtimeChannelV2?
    private var pollingTask: Task<Void, Never>?


    deinit {
        if let channel = realtimeChannel {
            let client = supabase
            Task {
                await client.removeChannel(channel)
            }
        }
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
        startRealtimeSubscription()
        isLoading = false
    }

    func startRealtimeSubscription() {
        stopRealtimeSubscription()

        let channel = supabase.channel("mechanic-realtime-updates")
        self.realtimeChannel = channel

        let serviceRequestStream = channel.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "service_requests"
        )

        let bidsStream = channel.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "bids"
        )

        Task { [weak self] in
            guard let self = self else { return }
            await channel.subscribe()

            // Listen to service_requests changes
            Task { [weak self] in
                for await _ in serviceRequestStream {
                    await self?.loadOrders()
                }
            }

            // Listen to bids changes (e.g., bid accepted/rejected)
            Task { [weak self] in
                for await _ in bidsStream {
                    await self?.loadOrders()
                }
            }
        }
        
        // Add polling as a robust fallback
        startPolling()
    }

    private func startPolling() {
        stopPolling()
        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
                guard !Task.isCancelled else { break }
                await self?.loadOrders()
            }
        }
    }

    private func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    func stopRealtimeSubscription() {
        if let channel = realtimeChannel {
            Task {
                await supabase.removeChannel(channel)
            }
            realtimeChannel = nil
        }
        stopPolling()
    }

    func loadOrders() async {
        guard let bengkel = myBengkel, let bengkelId = bengkel.id else { return }
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
            let nearbyOrders = response.orders

            // Fetch all bids placed by this bengkel
            let allMyBids: [Bid] = try await supabase.from("bids")
                .select()
                .eq("bengkel_id", value: bengkelId)
                .execute()
                .value

            let rejectedRequestIds = Set(allMyBids.filter { $0.status.lowercased() == "rejected" || $0.status.lowercased() == "autorejected" }.map { $0.serviceRequestId })
            self.myPendingBids = allMyBids.filter { $0.status.lowercased() == "pending" }

            // Filter out orders that have a rejected bid from this bengkel
            self.orders = nearbyOrders.filter { !rejectedRequestIds.contains($0.id) }
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

    func rejectBid(_ bid: Bid) async {
        do {
            try await supabase.from("bids")
                .update(BidStatusUpdate(status: "Rejected"))
                .eq("id", value: bid.id)
                .execute()
            await loadOrders()
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }
}
