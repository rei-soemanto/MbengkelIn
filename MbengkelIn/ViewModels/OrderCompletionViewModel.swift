import SwiftUI
import Combine
import Supabase

@MainActor
class OrderCompletionViewModel: ObservableObject {
    @Published var order: NearbyOrder?
    @Published var isLoading = false
    @Published var errorMessage: String?

    let requestId: String
    let isCustomer: Bool

    private let orderRepository = OrderRepository()
    private var realtimeChannel: RealtimeChannelV2?

    nonisolated init(requestId: String, isCustomer: Bool) {
        self.requestId = requestId
        self.isCustomer = isCustomer
    }

    deinit {
        if let channel = realtimeChannel {
            let client = supabase
            Task { await client.removeChannel(channel) }
        }
    }

    var status: String { order?.status ?? "On Progress" }
    var isFinished: Bool { status == "Done" || status == "Cancelled" }
    var mySideCompleted: Bool {
        isCustomer ? (order?.customerCompleted ?? false) : (order?.providerCompleted ?? false)
    }

    func start() async {
        await refresh()
        startRealtimeSubscription()
    }

    func refresh() async {
        do {
            self.order = try await orderRepository.fetchOrder(id: requestId)
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }

    func startRealtimeSubscription() {
        stopRealtimeSubscription()
        let channel = supabase.channel("order-completion-\(requestId)")
        self.realtimeChannel = channel
        let stream = channel.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "service_requests",
            filter: "id=eq.\(requestId)"
        )
        Task { [weak self] in
            guard let self = self else { return }
            await channel.subscribe()
            for await _ in stream { await self.refresh() }
        }
    }

    func stopRealtimeSubscription() {
        if let channel = realtimeChannel {
            Task { await supabase.removeChannel(channel) }
            realtimeChannel = nil
        }
    }

    func markCompleted() async {
        isLoading = true
        errorMessage = nil
        do {
            self.order = try await orderRepository.markOrderCompleted(requestId: requestId)
        } catch {
            self.errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
