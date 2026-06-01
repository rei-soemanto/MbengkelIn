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
    private let storageService = StorageService()
    private let notificationService = NotificationService()
    private var realtimeChannel: RealtimeChannelV2?
    // realtime reader tasks for this @MainActor view model
    private var realtimeReaderTasks: [Task<Void, Never>] = []
    private var hasLoadedOnce = false

    nonisolated init(requestId: String, isCustomer: Bool) {
        self.requestId = requestId
        self.isCustomer = isCustomer
    }

    // @MainActor view model deinit
    deinit {
        realtimeReaderTasks.forEach { $0.cancel() }
        realtimeReaderTasks.removeAll()
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

    @MainActor
    func start() async {
        notificationService.requestAuthorization()
        await refresh()
        startRealtimeSubscription()
    }

    @MainActor
    func refresh() async {
        do {
            let updated = try await orderRepository.fetchOrder(id: requestId)
            notifyOnCounterpartCompletion(previous: order, updated: updated)
            self.order = updated
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }

    // Each device only reacts to the OPPOSITE party's completion flag flipping,
    // so the actor never notifies itself.
    @MainActor
    private func notifyOnCounterpartCompletion(previous: NearbyOrder?, updated: NearbyOrder) {
        defer { hasLoadedOnce = true }
        guard hasLoadedOnce, let previous else { return }

        if isCustomer,
           !(previous.providerCompleted ?? false),
           (updated.providerCompleted ?? false) {
            notificationService.notifyNewOrder(
                title: "Bengkel menyelesaikan pesanan",
                body: "Bengkel telah menandai pekerjaan selesai."
            )
        }
        if !isCustomer,
           !(previous.customerCompleted ?? false),
           (updated.customerCompleted ?? false) {
            notificationService.notifyNewOrder(
                title: "Pelanggan menyelesaikan pesanan",
                body: "Pelanggan telah menandai pekerjaan selesai."
            )
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
        realtimeReaderTasks.append(Task { [weak self] in
            guard let self = self else { return }
            await channel.subscribe()
            for await _ in stream { await self.refresh() }
        })
    }

    // @MainActor teardown
    func stopRealtimeSubscription() {
        realtimeReaderTasks.forEach { $0.cancel() }
        realtimeReaderTasks.removeAll()
        if let channel = realtimeChannel {
            Task { await supabase.removeChannel(channel) }
            realtimeChannel = nil
        }
    }

    @MainActor
    func markCompleted(photoData: Data? = nil) async {
        isLoading = true
        errorMessage = nil
        do {
            var photoUrl: String? = nil
            if let photoData {
                let uid = try await supabase.auth.session.user.id.uuidString.lowercased()
                photoUrl = try await storageService.uploadOrderPhoto(uid: uid, data: photoData)
            }
            self.order = try await orderRepository.markOrderCompleted(requestId: requestId, completionPhotoUrl: photoUrl)
        } catch {
            self.errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
