import Combine
import Foundation
import Network

// Observes network reachability via NWPathMonitor. `isConnected` starts true so
// the UI doesn't flash the offline screen before the first path update arrives.
@MainActor
final class NetworkMonitor: ObservableObject {
    @Published var isConnected = true

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let connected = path.status == .satisfied
            Task { @MainActor in self?.isConnected = connected }
        }
        monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }
}
