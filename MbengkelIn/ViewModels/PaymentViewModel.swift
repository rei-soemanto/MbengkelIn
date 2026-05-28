import SwiftUI
import Combine
import Supabase

struct PaymentTarget: Identifiable {
    let id = UUID()
    let url: URL
}

@MainActor
class PaymentViewModel: ObservableObject {
    @Published var balance: Double = 0
    @Published var topups: [Topup] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    @Published var paymentTarget: PaymentTarget?
    @Published private(set) var currentOrderId: String?

    let presetAmounts: [Int] = [25000, 50000, 100000, 200000, 500000]

    private let authService = AuthService()
    private let userRepository = UserRepository()
    private let topupRepository = TopupRepository()
    private let paymentService = PaymentService()

    func refresh() async {
        guard let session = try? await authService.getCurrentSession() else { return }
        let uid = session.user.id.uuidString.lowercased()
        do {
            async let user = userRepository.fetchUser(uid: uid)
            async let history = topupRepository.fetchTopups(userId: uid)
            self.balance = try await user.balance
            self.topups = try await history
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }

    func startTopup(amount: Int) async {
        guard amount >= 10000 else {
            self.errorMessage = "Minimal top up Rp10.000"
            return
        }
        isLoading = true
        errorMessage = nil
        do {
            let response = try await paymentService.createTopup(amount: amount)
            self.currentOrderId = response.order_id
            if let url = URL(string: response.redirect_url) {
                self.paymentTarget = PaymentTarget(url: url)
            } else {
                self.errorMessage = "URL pembayaran tidak valid."
            }
        } catch {
            self.errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    // Called when the Midtrans WebView sheet is dismissed. The webhook credits
    // the balance asynchronously, so poll a few times before refreshing.
    func paymentFlowFinished() async {
        guard let orderId = currentOrderId else {
            await refresh()
            return
        }
        for _ in 0..<6 {
            if let topup = try? await topupRepository.fetchTopup(orderId: orderId),
               topup.status.lowercased() != "pending" {
                break
            }
            try? await Task.sleep(nanoseconds: 2_000_000_000)
        }
        currentOrderId = nil
        await refresh()
    }
}
