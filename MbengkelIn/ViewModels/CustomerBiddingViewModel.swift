import SwiftUI
import Combine
import Supabase

@MainActor
final class CustomerBiddingViewModel: ObservableObject {
    private let authService = AuthService()
    @Published var bids: [Bid] = []
    @Published var acceptedBid: Bid?
    @Published var isLoading = false
    @Published var isStartingSearch = false
    @Published var errorMessage: String?
    @Published var loadingPhase: LoadingPhase = .idle

    @Published var minPrice: Int = 0
    @Published var customerBidPrice: Int = 0
    @Published var isSearching = false

    @Published var serviceRequestId: String?
    @Published var balance: Double = 0
    @Published var showRetryPrompt = false
    @Published var shouldDismiss = false
    @Published var searchSecondsRemaining: Int = 0

    var searchTotalSeconds: Int { Int(searchTimeoutSeconds) }
    var searchProgress: Double {
        guard searchTotalSeconds > 0 else { return 0 }
        return Double(searchSecondsRemaining) / Double(searchTotalSeconds)
    }
    let serviceType: ServiceType
    let latitude: Double
    let longitude: Double
    let tireCount: Int
    let photoUrls: [String]
    let vehicleId: String?
    let vehicleInfo: String?

    private let searchTimeoutSeconds: UInt64 = 120
    private let decisionTimeoutSeconds: UInt64 = 10
    // How long a received offer stays valid before it is auto-rejected.
    private let bidDecisionWindowSeconds: TimeInterval = 120
    private var searchCountdownTask: Task<Void, Never>?
    private var decisionCountdownTask: Task<Void, Never>?
    // Fires at the nearest pending-offer deadline to auto-reject overdue offers.
    private var bidExpiryTask: Task<Void, Never>?

    private var realtimeChannel: RealtimeChannelV2?
    private var realtimeReaderTasks: [Task<Void, Never>] = []
    private let userRepository = UserRepository()
    private let orderRepository = OrderRepository()
    private let storageService = StorageService()
    private let notificationService = NotificationService()
    private var knownBidIds: Set<String> = []
    private var didLoadBidsOnce = false

    init(serviceType: ServiceType, latitude: Double, longitude: Double, tireCount: Int, photoUrls: [String], vehicleId: String? = nil, vehicleInfo: String? = nil) {
        self.serviceType = serviceType
        self.latitude = latitude
        self.longitude = longitude
        self.tireCount = tireCount
        self.photoUrls = photoUrls
        self.vehicleId = vehicleId
        self.vehicleInfo = vehicleInfo
        let base = serviceType.minPrice
        let isTire = serviceType.requiresTireCount
        let min = isTire ? base * tireCount : base
        self.minPrice = min
        self.customerBidPrice = min
    }

    convenience init(resuming order: NearbyOrder) {
        let type = ServiceType(rawValue: order.serviceType ?? "") ?? .banGembos
        self.init(
            serviceType: type,
            latitude: order.latitude,
            longitude: order.longitude,
            tireCount: order.tireCount ?? 1,
            photoUrls: order.photoUrls ?? [],
            vehicleId: order.vehicleId,
            vehicleInfo: order.vehicleInfo
        )
        self.serviceRequestId = order.id
        self.customerBidPrice = order.price ?? self.minPrice
        self.isSearching = true
    }

    func resume() async {
        guard serviceRequestId != nil else { return }
        isSearching = true
        startRealtimeSubscription()
        await loadReceivedBids()
        if bids.isEmpty && acceptedBid == nil {
            startSearchCountdown()
        }
    }

    deinit {
        searchCountdownTask?.cancel()
        decisionCountdownTask?.cancel()
        bidExpiryTask?.cancel()
        realtimeReaderTasks.forEach { $0.cancel() }
        realtimeReaderTasks.removeAll()
        if let channel = realtimeChannel {
            Task {
                await supabase.removeChannel(channel)
            }
        }
    }

    func startSearch(price: Int) async {
        guard price >= minPrice else {
            self.errorMessage = "Harga penawaran harus minimal Rp\(minPrice)"
            return
        }

        isStartingSearch = true
        errorMessage = nil
        notificationService.requestAuthorization()
        loadingPhase = .loading(message: "Membuat pesanan...")
        do {
            let uid = try await authService.currentUID()
            let user = try await userRepository.fetchUser(uid: uid)
            self.balance = user.balance
            // If re-searching an existing order, its current hold is added back before checking.
            let existingHold = serviceRequestId != nil ? Double(customerBidPrice) : 0
            let available = user.availableBalance + existingHold
            guard Double(price) <= available else {
                self.errorMessage = "Saldo tidak cukup. Tawaran Rp\(price), saldo tersedia Rp\(Int(available))."
                loadingPhase = .idle
                isStartingSearch = false
                return
            }

            if let existingId = serviceRequestId {
                try await supabase.from("service_requests")
                    .update(StartSearchPayload(price: price))
                    .eq("id", value: existingId)
                    .execute()
            } else {
                let payload = ServiceRequestPayload(
                    customer_id: uid,
                    service_type: serviceType,
                    description: serviceType.rawValue,
                    latitude: latitude,
                    longitude: longitude,
                    price: price,
                    is_emergency: false,
                    status: "To Do",
                    tire_count: tireCount,
                    photo_urls: photoUrls,
                    vehicle_id: vehicleId,
                    vehicle_info: vehicleInfo
                )
                let created = try await orderRepository.createOrder(payload: payload)
                self.serviceRequestId = created.id
            }

            self.customerBidPrice = price
            self.isSearching = true
            self.showRetryPrompt = false
            loadingPhase = .idle

            startRealtimeSubscription()
            await loadReceivedBids()
            startSearchCountdown()
        } catch {
            self.errorMessage = error.localizedDescription
            loadingPhase = .failed(title: "Gagal memulai pencarian", message: error.localizedDescription)
        }
        isStartingSearch = false
    }

    private func startSearchCountdown() {
        searchCountdownTask?.cancel()
        decisionCountdownTask?.cancel()
        guard bids.isEmpty, acceptedBid == nil else { return }
        searchSecondsRemaining = searchTotalSeconds
        searchCountdownTask = Task { [weak self] in
            guard let self else { return }
            while self.searchSecondsRemaining > 0 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                if Task.isCancelled { return }
                self.searchSecondsRemaining -= 1
            }
            if Task.isCancelled { return }
            self.searchCountdownTask = nil
            if self.bids.isEmpty && self.acceptedBid == nil && self.isSearching {
                self.expireSearch()
            }
        }
    }

    private func expireSearch() {
        showRetryPrompt = true
        decisionCountdownTask?.cancel()
        decisionCountdownTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: self.decisionTimeoutSeconds * 1_000_000_000)
            if Task.isCancelled { return }
            if self.showRetryPrompt {
                await self.cancelAndDelete()
            }
        }
    }

    func retrySamePrice() {
        showRetryPrompt = false
        decisionCountdownTask?.cancel()
        startSearchCountdown()
    }

    func raisePrice() {
        showRetryPrompt = false
        searchCountdownTask?.cancel()
        decisionCountdownTask?.cancel()
        bidExpiryTask?.cancel()
        bidExpiryTask = nil
        isSearching = false
    }

    private func stopSearchingState() {
        searchCountdownTask?.cancel()
        searchCountdownTask = nil
        decisionCountdownTask?.cancel()
        decisionCountdownTask = nil
        bidExpiryTask?.cancel()
        bidExpiryTask = nil
        searchSecondsRemaining = 0
        showRetryPrompt = false
        isSearching = false
    }

    func cancelAndDelete() async {
        showRetryPrompt = false
        searchCountdownTask?.cancel()
        decisionCountdownTask?.cancel()
        bidExpiryTask?.cancel()
        bidExpiryTask = nil
        stopRealtimeSubscription()
        if let id = serviceRequestId, bids.isEmpty {
            try? await orderRepository.deleteOrder(id: id)
            if !photoUrls.isEmpty {
                try? await storageService.deleteOrderPhotos(urls: photoUrls)
            }
        }
        shouldDismiss = true
    }

    func cancel() async {
        showRetryPrompt = false
        searchCountdownTask?.cancel()
        decisionCountdownTask?.cancel()
        bidExpiryTask?.cancel()
        bidExpiryTask = nil
        stopRealtimeSubscription()
        if let id = serviceRequestId {
            try? await orderRepository.cancelOrder(id: id)
        }
        shouldDismiss = true
    }

    func startRealtimeSubscription() {
        stopRealtimeSubscription()
        guard let serviceRequestId = serviceRequestId else { return }

        let channel = supabase.channel("bids-updates-\(serviceRequestId)")
        self.realtimeChannel = channel

        let stream = channel.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "bids",
            filter: .eq("service_request_id", value: serviceRequestId)
        )

        realtimeReaderTasks.append(Task { [weak self] in
            guard let self = self else { return }
            try? await channel.subscribeWithError()
            // Cold-start reconcile after the channel is confirmed subscribed, in
            // case a bid landed during the subscribe handshake.
            await self.loadReceivedBids()

            for await _ in stream {
                await self.loadReceivedBids()
            }
        })

    }

    func stopRealtimeSubscription() {
        realtimeReaderTasks.forEach { $0.cancel() }
        realtimeReaderTasks.removeAll()
        if let channel = realtimeChannel {
            Task {
                await supabase.removeChannel(channel)
            }
            realtimeChannel = nil
        }
    }

    func loadReceivedBids() async {
        guard let serviceRequestId = serviceRequestId else { return }
        do {
            let fetched: [Bid] = try await supabase.from("bids")
                .select("*, bengkel:bengkels(*)")
                .eq("service_request_id", value: serviceRequestId)
                .order("price", ascending: true)
                .execute()
                .value
            let pending = fetched.filter { $0.status.lowercased() == "pending" }

            // Push a notification for each offer that arrived since the last load.
            if didLoadBidsOnce {
                for bid in pending where !knownBidIds.contains(bid.id) {
                    notificationService.notifyNewOrder(
                        title: "Tawaran baru masuk!",
                        body: "\(bid.bengkel?.name ?? "Sebuah bengkel") menawar Rp\(bid.price)."
                    )
                }
            }
            knownBidIds = Set(pending.map { $0.id })
            didLoadBidsOnce = true

            self.bids = pending
            if pending.isEmpty {
                // Offers drained (all rejected/expired): stop the deadline watcher
                // and, if still searching, resume the search countdown so the flow
                // keeps moving instead of freezing on a stuck timer.
                bidExpiryTask?.cancel()
                bidExpiryTask = nil
                if isSearching, acceptedBid == nil, !showRetryPrompt, searchCountdownTask == nil {
                    startSearchCountdown()
                }
            } else {
                // Offers present: pause the search countdown, arm the auto-reject watcher.
                searchCountdownTask?.cancel()
                searchCountdownTask = nil
                decisionCountdownTask?.cancel()
                showRetryPrompt = false
                scheduleBidExpiry()
            }
            if let accepted = fetched.first(where: { $0.status.lowercased() == "accepted" }) {
                self.acceptedBid = accepted
                stopRealtimeSubscription()
                stopSearchingState()
            }
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }

    func refresh() async {
        errorMessage = nil
        if isSearching {
            await loadReceivedBids()
        }
    }

    func acceptBid(_ bid: Bid) async {
        isLoading = true
        errorMessage = nil
        do {
            _ = try await orderRepository.acceptBid(bidId: bid.id)
            stopRealtimeSubscription()
            await loadReceivedBids()
            if self.acceptedBid == nil {
                self.acceptedBid = bid
            }
            stopSearchingState()
        } catch {
            self.errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func rejectBid(_ bid: Bid) async {
        isLoading = true
        errorMessage = nil
        do {
            try await supabase.from("bids")
                .update(BidStatusUpdate(status: "Rejected"))
                .eq("id", value: bid.id)
                .execute()

            await loadReceivedBids()
        } catch {
            self.errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    // The offer's response window elapsed without the customer deciding. This is
    // a timeout (status "Expired") — distinct from "AutoRejected", which means
    // the customer accepted a different bengkel.
    func expireBid(_ bid: Bid) async {
        do {
            try await supabase.from("bids")
                .update(BidStatusUpdate(status: "Expired"))
                .eq("id", value: bid.id)
                .execute()

            await loadReceivedBids()
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }

    // Arms one timer that fires at the soonest pending-offer deadline.
    private func scheduleBidExpiry() {
        bidExpiryTask?.cancel()
        let deadlines = bids.compactMap { bid -> Date? in
            guard bid.status.lowercased() == "pending",
                  let s = bid.createdAt, let created = Self.parseISODate(s) else { return nil }
            return created.addingTimeInterval(bidDecisionWindowSeconds)
        }
        guard let next = deadlines.min() else { return }
        let delay = max(0, next.timeIntervalSinceNow)
        bidExpiryTask = Task { [weak self] in
            if delay > 0 { try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000)) }
            if Task.isCancelled { return }
            await self?.expireOverdueBids()
        }
    }

    // Auto-rejects every pending offer whose decision window has elapsed.
    private func expireOverdueBids() async {
        let now = Date()
        let overdue = bids.filter { bid in
            guard bid.status.lowercased() == "pending",
                  let s = bid.createdAt, let created = Self.parseISODate(s) else { return false }
            return now.timeIntervalSince(created) >= bidDecisionWindowSeconds
        }
        guard !overdue.isEmpty else { scheduleBidExpiry(); return } // woke early -> re-arm
        for bid in overdue {
            _ = try? await supabase.from("bids")
                .update(BidStatusUpdate(status: "Expired"))
                .eq("id", value: bid.id)
                .execute()
        }
        await loadReceivedBids() // re-arms watcher, or resumes search if none remain
    }

    // Supabase timestamps carry up to 6 fractional digits; add a strip-fallback.
    static func parseISODate(_ s: String) -> Date? {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f.date(from: s) { return d }
        f.formatOptions = [.withInternetDateTime]
        if let d = f.date(from: s) { return d }
        if let r = s.range(of: #"\.\d+"#, options: .regularExpression) {
            f.formatOptions = [.withInternetDateTime]
            return f.date(from: s.replacingCharacters(in: r, with: ""))
        }
        return nil
    }
}
