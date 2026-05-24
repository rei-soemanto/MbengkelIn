import SwiftUI
import Combine
import Supabase

@MainActor
class CustomerBiddingViewModel: ObservableObject {
    @Published var mechanics: [NearbyMechanic] = []
    @Published var bids: [Bid] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var loadingPhase: LoadingPhase = .idle

    let serviceRequestId: String
    let latitude: Double
    let longitude: Double

    private var searchTask: Task<Void, Never>?
    private let searchTimeout: TimeInterval = 120
    private let pollInterval: UInt64 = 5_000_000_000

    private struct MechanicsRequest: Encodable {
        let action: String
        let latitude: Double
        let longitude: Double
        let radiusMeters: Double
    }

    private struct MechanicsResponse: Decodable {
        let mechanics: [NearbyMechanic]
    }

    private struct BengkelUpdate: Encodable {
        let bengkel_id: String
        let status: String
    }

    private struct BidStatusUpdate: Encodable {
        let status: String
    }

    init(serviceRequestId: String, latitude: Double, longitude: Double) {
        self.serviceRequestId = serviceRequestId
        self.latitude = latitude
        self.longitude = longitude
    }

    func searchForMechanics() {
        searchTask?.cancel()
        loadingPhase = .loading(message: "Mencari mekanik terdekat...")
        searchTask = Task { await runSearch() }
    }

    private func runSearch() async {
        let deadline = Date().addingTimeInterval(searchTimeout)
        while !Task.isCancelled {
            await loadNearbyMechanics()
            await loadReceivedBids()

            if !mechanics.isEmpty || !bids.isEmpty {
                loadingPhase = .idle
                return
            }

            if Date() >= deadline {
                loadingPhase = .failed(
                    title: "Oops, gagal menemukan mekanik",
                    message: "Tidak ada mekanik dalam jarak 5km."
                )
                return
            }

            try? await Task.sleep(nanoseconds: pollInterval)
        }
    }

    func stopSearch() {
        searchTask?.cancel()
        searchTask = nil
        loadingPhase = .idle
    }

    func loadNearbyMechanics() async {
        do {
            let body = MechanicsRequest(
                action: "mechanicsForCustomer",
                latitude: latitude,
                longitude: longitude,
                radiusMeters: 5000
            )
            let response: MechanicsResponse = try await supabase.functions.invoke(
                "bidding",
                options: FunctionInvokeOptions(body: body)
            )
            self.mechanics = response.mechanics
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }

    func loadReceivedBids() async {
        do {
            let fetched: [Bid] = try await supabase.from("bids")
                .select()
                .eq("service_request_id", value: serviceRequestId)
                .order("price", ascending: true)
                .execute()
                .value
            self.bids = fetched
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }

    func refresh() async {
        isLoading = true
        errorMessage = nil
        await loadNearbyMechanics()
        await loadReceivedBids()
        isLoading = false
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

            await loadReceivedBids()
        } catch {
            self.errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
