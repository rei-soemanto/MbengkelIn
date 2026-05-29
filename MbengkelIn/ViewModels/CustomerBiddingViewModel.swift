import SwiftUI
import Combine
import Supabase

@MainActor
class CustomerBiddingViewModel: ObservableObject {
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

    private let searchTimeoutSeconds: UInt64 = 120
    private let decisionTimeoutSeconds: UInt64 = 10
    private var searchCountdownTask: Task<Void, Never>?
    private var decisionCountdownTask: Task<Void, Never>?

    private var realtimeChannel: RealtimeChannelV2?
    private let userRepository = UserRepository()
    private let orderRepository = OrderRepository()
    private let storageService = StorageService()

    let serviceMinPrices: [String: Int] = [
        "Aki Kering": 60000,
        "Ban Gembos": 25000,
        "Ban Pecah": 40000
    ]


    init(serviceType: ServiceType, latitude: Double, longitude: Double, tireCount: Int, photoUrls: [String]) {
        self.serviceType = serviceType
        self.latitude = latitude
        self.longitude = longitude
        self.tireCount = tireCount
        self.photoUrls = photoUrls
        let base = serviceMinPrices[serviceType.rawValue] ?? 40000
        let isTire = serviceType == .banGembos || serviceType == .banPecah
        let min = isTire ? base * tireCount : base
        self.minPrice = min
        self.customerBidPrice = min
    }

    deinit {
        searchCountdownTask?.cancel()
        decisionCountdownTask?.cancel()
        if let channel = realtimeChannel {
            let client = supabase
            Task {
                await client.removeChannel(channel)
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
        loadingPhase = .loading(message: "Membuat pesanan...")
        do {
            let uid = try await supabase.auth.session.user.id.uuidString.lowercased()
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
                    photo_urls: photoUrls
                )
                let created: CreatedServiceRequest = try await supabase.from("service_requests")
                    .insert(payload)
                    .select("id")
                    .single()
                    .execute()
                    .value
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
        isSearching = false
    }

    func cancelAndDelete() async {
        showRetryPrompt = false
        searchCountdownTask?.cancel()
        decisionCountdownTask?.cancel()
        stopRealtimeSubscription()
        if let id = serviceRequestId, bids.isEmpty {
            try? await orderRepository.deleteOrder(id: id)
            if !photoUrls.isEmpty {
                try? await storageService.deleteOrderPhotos(urls: photoUrls)
            }
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
            filter: "service_request_id=eq.\(serviceRequestId)"
        )

        Task { [weak self] in
            guard let self = self else { return }
            await channel.subscribe()

            for await _ in stream {
                await self.loadReceivedBids()
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

    func loadReceivedBids() async {
        guard let serviceRequestId = serviceRequestId else { return }
        do {
            let fetched: [Bid] = try await supabase.from("bids")
                .select("*, bengkel:bengkels(*)")
                .eq("service_request_id", value: serviceRequestId)
                .order("price", ascending: true)
                .execute()
                .value
            self.bids = fetched.filter { $0.status.lowercased() == "pending" }
            if !self.bids.isEmpty {
                searchCountdownTask?.cancel()
                decisionCountdownTask?.cancel()
                showRetryPrompt = false
            }
            if let accepted = fetched.first(where: { $0.status.lowercased() == "accepted" }) {
                self.acceptedBid = accepted
                stopRealtimeSubscription()
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
        guard let serviceRequestId = serviceRequestId else { return }
        isLoading = true
        errorMessage = nil
        do {
            let uid = try await supabase.auth.session.user.id.uuidString.lowercased()
            let user = try await userRepository.fetchUser(uid: uid)
            self.balance = user.balance
            // This order already holds `customerBidPrice`; accepting swaps that hold to bid.price.
            let available = user.availableBalance + Double(customerBidPrice)
            guard Double(bid.price) <= available else {
                self.errorMessage = "Saldo tidak cukup untuk menerima tawaran Rp\(bid.price). Saldo tersedia Rp\(Int(available))."
                isLoading = false
                return
            }

            try await supabase.from("bids")
                .update(BidStatusUpdate(status: "Accepted"))
                .eq("id", value: bid.id)
                .execute()

            // Reject every other bid on this request so the losing bengkels
            // have the order removed and get alerted (realtime on their side).
            try await supabase.from("bids")
                .update(BidStatusUpdate(status: "AutoRejected"))
                .eq("service_request_id", value: serviceRequestId)
                .neq("id", value: bid.id)
                .execute()

            try await supabase.from("service_requests")
                .update(AcceptOrderPayload(bengkel_id: bid.bengkelId, status: "On Progress", price: bid.price))
                .eq("id", value: serviceRequestId)
                .execute()

            stopRealtimeSubscription()
            await loadReceivedBids()
            if self.acceptedBid == nil {
                self.acceptedBid = bid
            }
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

    func autoRejectBid(_ bid: Bid) async {
        do {
            try await supabase.from("bids")
                .update(BidStatusUpdate(status: "AutoRejected"))
                .eq("id", value: bid.id)
                .execute()

            await loadReceivedBids()
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }
}
