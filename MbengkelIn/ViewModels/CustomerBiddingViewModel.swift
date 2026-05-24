import SwiftUI
import Combine
import Supabase

@MainActor
class CustomerBiddingViewModel: ObservableObject {
    @Published var bids: [Bid] = []
    @Published var isLoading = false
    @Published var isStartingSearch = false
    @Published var errorMessage: String?
    @Published var loadingPhase: LoadingPhase = .idle

    // Real-time and pricing states
    @Published var serviceRequest: NearbyOrder?
    @Published var minPrice: Int = 0
    @Published var customerBidPrice: Int = 0
    @Published var isSearching = false

    let serviceRequestId: String
    let latitude: Double
    let longitude: Double

    private var realtimeChannel: RealtimeChannelV2?
    private var pollingTask: Task<Void, Never>?

    let serviceMinPrices: [String: Int] = [
        "Engine": 100000,
        "Tire": 40000,
        "Battery": 60000,
        "Towing": 150000
    ]

    private struct BengkelUpdate: Encodable {
        let bengkel_id: String
        let status: String
    }

    private struct BidStatusUpdate: Encodable {
        let status: String
    }

    private struct StartSearchPayload: Encodable {
        let price: Int
    }

    init(serviceRequestId: String, latitude: Double, longitude: Double) {
        self.serviceRequestId = serviceRequestId
        self.latitude = latitude
        self.longitude = longitude
    }

    deinit {
        if let channel = realtimeChannel {
            let client = supabase
            Task {
                await client.removeChannel(channel)
            }
        }
    }

    func loadServiceRequest() async {
        isLoading = true
        errorMessage = nil
        do {
            let fetched: NearbyOrder = try await supabase.from("service_requests")
                .select()
                .eq("id", value: serviceRequestId)
                .single()
                .execute()
                .value
            self.serviceRequest = fetched
            
            let desc = fetched.description ?? "Tire"
            self.minPrice = serviceMinPrices[desc] ?? 40000
            
            if let price = fetched.price, price > 0 {
                self.customerBidPrice = price
            } else {
                self.customerBidPrice = self.minPrice
            }

            // Recover searching state based on local logic if needed,
            // but for now we require the user to explicitly click "Temukan Mekanik"
            // if they reload the view, to confirm their price.
        } catch {
            self.errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func startSearch(price: Int) async {
        guard price >= minPrice else {
            self.errorMessage = "Harga penawaran harus minimal Rp\(minPrice)"
            return
        }
        
        isStartingSearch = true
        errorMessage = nil
        loadingPhase = .loading(message: "Memulai pencarian...")
        do {
            try await supabase.from("service_requests")
                .update(StartSearchPayload(price: price))
                .eq("id", value: serviceRequestId)
                .execute()

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
        
        // Add polling as a robust fallback in case database replication is disabled
        startPolling()
    }

    private func startPolling() {
        stopPolling()
        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
                guard !Task.isCancelled else { break }
                await self?.loadReceivedBids()
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

    func loadReceivedBids() async {
        do {
            let fetched: [Bid] = try await supabase.from("bids")
                .select("*, bengkel:bengkels(*)")
                .eq("service_request_id", value: serviceRequestId)
                .order("price", ascending: true)
                .execute()
                .value
            // Only show Pending bids — expired/rejected bids are hidden
            // Check case-insensitively just in case the edge function uses 'pending'
            self.bids = fetched.filter { $0.status.lowercased() == "pending" }
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }

    func refresh() async {
        errorMessage = nil
        await loadServiceRequest()
        if isSearching {
            await loadReceivedBids()
        }
    }

    func acceptBid(_ bid: Bid) async {
        isLoading = true
        errorMessage = nil
        do {
            try await supabase.from("bids")
                .update(BidStatusUpdate(status: "Accepted"))
                .eq("id", value: bid.id)
                .execute()

            try await supabase.from("service_requests")
                .update(BengkelUpdate(bengkel_id: bid.bengkelId, status: "On Progress"))
                .eq("id", value: serviceRequestId)
                .execute()

            // Stop realtime since order is accepted
            stopRealtimeSubscription()
            
            await loadReceivedBids()
            await loadServiceRequest()
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
