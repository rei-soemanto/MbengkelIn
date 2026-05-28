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
    private let notificationService = NotificationService()
    private var knownOrderIds: Set<String> = []
    private var didInitialLoad = false
    private var providerUid: String?


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
        notificationService.requestAuthorization()
        do {
            let uid = try await supabase.auth.session.user.id.uuidString.lowercased()
            self.providerUid = uid
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
        guard let uid = providerUid else { return }

        let channel = supabase.channel("mechanic-bids-\(uid)")
        self.realtimeChannel = channel

        // Primary signal: this mechanic's own bids. When the customer accepts
        // or rejects a bid, the row changes and we refresh in real time.
        let bidsStream = channel.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "bids",
            filter: "provider_uid=eq.\(uid)"
        )

        // Secondary signal: nearby service_requests change (new orders, price edits).
        let serviceRequestStream = channel.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "service_requests"
        )

        Task { [weak self] in
            guard let self = self else { return }
            await channel.subscribe()

            Task { [weak self] in
                for await _ in bidsStream {
                    await self?.loadOrders()
                }
            }

            Task { [weak self] in
                for await _ in serviceRequestStream {
                    await self?.loadOrders()
                }
            }
        }
    }

    func stopRealtimeSubscription() {
        if let channel = realtimeChannel {
            Task {
                await supabase.removeChannel(channel)
            }
            realtimeChannel = nil
        }
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
            let filteredOrders = nearbyOrders.filter { !rejectedRequestIds.contains($0.id) }

            // Notify for orders that appeared after we started watching (not the first load).
            let currentIds = Set(filteredOrders.map { $0.id })
            if didInitialLoad {
                for order in filteredOrders where !knownOrderIds.contains(order.id) {
                    let meters = Int(order.distanceM ?? 0)
                    notificationService.notifyNewOrder(
                        title: "Order baru di sekitar!",
                        body: "\(order.description ?? order.serviceType ?? "Permintaan servis") • \(meters) m"
                    )
                }
            }
            knownOrderIds = currentIds
            didInitialLoad = true

            self.orders = filteredOrders
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
