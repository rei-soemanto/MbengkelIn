import SwiftUI
import Combine
import Supabase

@MainActor
class BengkelBiddingViewModel: ObservableObject {
    // @MainActor (class-level annotation also applies to all members below).
    @Published var orders: [NearbyOrder] = []
    @Published var myBengkel: Bengkel?
    @Published var myPendingBids: [Bid] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?

    // Drives the in-app modal that pops when a brand-new order arrives.
    @Published var newOrderAlert: NearbyOrder?
    // Set when a pending bid is lost because the customer picked another bengkel.
    @Published var lostBidAlert: String?
    // Set when an order's response window simply elapsed (timeout, not a loss).
    @Published var expiredBidAlert: String?
    // The order screen the bengkel is currently taken into — set after placing
    // an offer (route map) and when the customer accepts (carries through to the
    // active order). Drives the full-screen route view.
    @Published var activeBengkelOrder: NearbyOrder?
    // Set when the customer declines our offer — we can re-bid a different amount.
    @Published var rejectedBidAlert: String?
    // Set when the mechanic tries to bid on an order that's no longer available
    // (cancelled / taken / deleted) — surfaced as an alert so it isn't silent.
    @Published var orderUnavailableAlert: String?
    // Orders where our latest bid was declined (kept visible so we can re-bid).
    @Published var myRejectedBids: [Bid] = []

    private var realtimeChannel: RealtimeChannelV2?
    private let orderRepository = OrderRepository()
    private let notificationService = NotificationService()
    private var knownOrderIds: Set<String> = []
    private var bidStatusById: [String: String] = [:]
    private var didInitialLoad = false
    private var hasStarted = false
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
        if hasStarted { return }
        hasStarted = true
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
            hasStarted = false
            return
        }
        await loadOrders()
        startRealtimeSubscription()
        isLoading = false
    }

    // Called when the app returns to the foreground: realtime sockets can die
    // while backgrounded, so reload missed orders and re-establish the channel.
    func refreshOnForeground() async {
        guard hasStarted else { return }
        print("[BengkelRT] foreground refresh + resubscribe")
        await loadOrders()
        startRealtimeSubscription()
    }

    @MainActor
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
            print("[BengkelRT] subscribing channel mechanic-bids-\(uid)")
            await channel.subscribe()
            print("[BengkelRT] channel subscribed")
            // Cold-start reconcile: the first realtime events after launch can
            // arrive during the subscribe handshake and be missed. Refetch once
            // the channel is confirmed subscribed so the first order isn't lost.
            // One-shot reconcile — NOT polling.
            // @MainActor (class-level annotation also applied to this method).
            await self.loadOrders()

            Task { [weak self] in
                for await _ in bidsStream {
                    print("[BengkelRT] bids change received")
                    await self?.loadOrders()
                }
            }

            Task { [weak self] in
                for await _ in serviceRequestStream {
                    print("[BengkelRT] service_requests change received")
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

    @MainActor
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

            // Detect bids the customer rejected by choosing another bengkel.
            // A pending bid flipping to AutoRejected means we lost the job.
            // A pending bid changing state tells us why we no longer have the job:
            //  - "autorejected": the customer accepted a different bengkel (taken)
            //  - "expired": the response window elapsed with no decision (timeout)
            // These are distinct events with distinct messages.
            if didInitialLoad {
                for bid in allMyBids where bidStatusById[bid.id] == "pending" {
                    switch bid.status.lowercased() {
                    case "accepted":
                        notificationService.notifyNewOrder(
                            title: "Tawaran diterima!",
                            body: "Pelanggan menerima tawaran Anda. Order otomatis dibuka."
                        )
                        // If the bengkel is already on this order's route screen,
                        // it updates in place via its own realtime subscription.
                        if self.activeBengkelOrder == nil,
                           let order = try? await self.orderRepository.fetchOrder(id: bid.serviceRequestId) {
                            self.activeBengkelOrder = order
                        }
                    case "autorejected":
                        notificationService.notifyNewOrder(
                            title: "Order diambil bengkel lain",
                            body: "Pelanggan memilih tawaran bengkel lain untuk order ini."
                        )
                        self.lostBidAlert = "Pelanggan memilih tawaran bengkel lain. Tawaran Anda tidak terpilih."
                    case "expired":
                        notificationService.notifyNewOrder(
                            title: "Waktu order habis",
                            body: "Pelanggan tidak menanggapi tepat waktu. Order kedaluwarsa."
                        )
                        self.expiredBidAlert = "Waktu order telah habis. Order kedaluwarsa karena pelanggan tidak menanggapi tepat waktu."
                    case "rejected":
                        notificationService.notifyNewOrder(
                            title: "Tawaran ditolak",
                            body: "Pelanggan menolak tawaran Anda. Anda bisa menawar ulang dengan harga lain."
                        )
                        self.rejectedBidAlert = "Pelanggan menolak tawaran Anda. Order masih terbuka — silakan ajukan harga lain."
                    default:
                        break
                    }
                }
            }
            bidStatusById = Dictionary(allMyBids.map { ($0.id, $0.status.lowercased()) }, uniquingKeysWith: { _, new in new })

            // "autorejected" (taken by another) and "expired" (timed out) are
            // terminal — drop those orders. A plain "rejected" (the customer
            // declined our price) keeps the order so we can re-bid.
            let terminalRequestIds = Set(allMyBids.filter { ["autorejected", "expired"].contains($0.status.lowercased()) }.map { $0.serviceRequestId })
            self.myPendingBids = allMyBids.filter { $0.status.lowercased() == "pending" }
            self.myRejectedBids = allMyBids.filter { $0.status.lowercased() == "rejected" }

            let filteredOrders = nearbyOrders.filter { !terminalRequestIds.contains($0.id) }

            // Notify for orders that appeared after we started watching (not the first load).
            let currentIds = Set(filteredOrders.map { $0.id })
            if didInitialLoad {
                for order in filteredOrders where !knownOrderIds.contains(order.id) {
                    let meters = Int(order.distanceM ?? 0)
                    notificationService.notifyNewOrder(
                        title: "Order baru di sekitar!",
                        body: "\(order.description ?? order.serviceType ?? "Permintaan servis") • \(meters) m"
                    )
                    self.newOrderAlert = order
                }
            }
            knownOrderIds = currentIds
            didInitialLoad = true

            self.orders = filteredOrders
            // If the incoming-order modal is showing an order that's no longer in
            // the open feed (cancelled/taken), dismiss it so it can't be bid on.
            // @MainActor (class-level annotation also applied to this method).
            if let alert = self.newOrderAlert, !currentIds.contains(alert.id) {
                self.newOrderAlert = nil
            }
            print("[BengkelRT] loadOrders -> \(filteredOrders.count) nearby order(s), didInitialLoad=\(didInitialLoad)")
        } catch {
            print("[BengkelRT] loadOrders error: \(error.localizedDescription)")
            self.errorMessage = error.localizedDescription
        }
    }

    @MainActor
    func placeBid(order: NearbyOrder, price: Int, notes: String) async {
        guard let bengkel = myBengkel, let bengkelId = bengkel.id else { return }
        // Re-verify the order is still open before bidding. It may have been
        // cancelled or taken while sitting in the feed; bidding on a dead order
        // pushes the mechanic into a stale active-order screen and crashes.
        // A cancelled/taken/deleted order fails the open-orders RLS read, so a
        // nil/failed fetch is also treated as "no longer available".
        guard let latest = try? await orderRepository.fetchOrder(id: order.id),
              latest.status == "To Do", latest.bengkelId == nil else {
            self.errorMessage = "Order sudah tidak tersedia."
            self.orderUnavailableAlert = "Order ini sudah dibatalkan atau diambil bengkel lain. Order telah ditutup."
            await loadOrders()
            return
        }
        let floor = order.price ?? 0
        guard price >= floor, price > 0 else {
            self.errorMessage = "Tawaran tidak boleh di bawah harga pelanggan (Rp\(floor))."
            return
        }
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
            // Take the bengkel to the live route-to-customer screen.
            self.activeBengkelOrder = order
            await loadOrders()
        } catch {
            self.errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    // When an order's 2-minute window elapses, drop it locally and reject any
    // bid we placed on it. The customer also deletes/expires the row server-side.
    @MainActor
    func handleExpiredOrder(_ order: NearbyOrder) async {
        orders.removeAll { $0.id == order.id }
        knownOrderIds.remove(order.id)
        if let bid = myPendingBids.first(where: { $0.serviceRequestId == order.id }) {
            await expireBid(bid)
        }
    }

    // The order's response window elapsed: mark our bid "Expired" (timeout),
    // not "Rejected"/"AutoRejected".
    func expireBid(_ bid: Bid) async {
        do {
            try await supabase.from("bids")
                .update(BidStatusUpdate(status: "Expired"))
                .eq("id", value: bid.id)
                .execute()
            await loadOrders()
        } catch {
            self.errorMessage = error.localizedDescription
        }
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
