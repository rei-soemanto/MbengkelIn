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
    let serviceType: ServiceType
    let latitude: Double
    let longitude: Double

    private var realtimeChannel: RealtimeChannelV2?

    let serviceMinPrices: [String: Int] = [
        "Aki Kering": 60000,
        "Ban Gembos": 25000,
        "Ban Pecah": 40000
    ]


    init(serviceType: ServiceType, latitude: Double, longitude: Double) {
        self.serviceType = serviceType
        self.latitude = latitude
        self.longitude = longitude
        let min = serviceMinPrices[serviceType.rawValue] ?? 40000
        self.minPrice = min
        self.customerBidPrice = min
    }

    deinit {
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
            if let existingId = serviceRequestId {
                try await supabase.from("service_requests")
                    .update(StartSearchPayload(price: price))
                    .eq("id", value: existingId)
                    .execute()
            } else {
                let uid = try await supabase.auth.session.user.id.uuidString.lowercased()
                let payload = ServiceRequestPayload(
                    customer_id: uid,
                    service_type: serviceType,
                    description: serviceType.rawValue,
                    latitude: latitude,
                    longitude: longitude,
                    price: price,
                    is_emergency: false,
                    status: "To Do"
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
            loadingPhase = .idle

            startRealtimeSubscription()
            await loadReceivedBids()
        } catch {
            self.errorMessage = error.localizedDescription
            loadingPhase = .failed(title: "Gagal memulai pencarian", message: error.localizedDescription)
        }
        isStartingSearch = false
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
                .update(BengkelUpdate(bengkel_id: bid.bengkelId, status: "On Progress"))
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
