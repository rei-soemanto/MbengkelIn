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
    @Published var heldBalance: Double = 0
    @Published var topups: [Topup] = []
    @Published var withdrawals: [Withdrawal] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?

    // Bank details (mirrored from the user profile).
    @Published var bankName: String = ""
    @Published var bankAccountNumber: String = ""
    @Published var bankAccountName: String = ""

    @Published var paymentTarget: PaymentTarget?
    @Published private(set) var currentOrderId: String?

    let presetAmounts: [Int] = [25000, 50000, 100000, 200000, 500000]

    // Keep these in sync with the `payment` edge function
    // (supabase/functions/payment/index.ts) amount validation.
    let minTopupAmount = 10_000
    let maxTopupAmount = 10_000_000

    var hasBankDetails: Bool {
        !bankAccountNumber.isEmpty && !bankName.isEmpty && !bankAccountName.isEmpty
    }

    // Withdrawable funds excluding escrow.
    var availableBalance: Double { max(0, balance - heldBalance) }

    private let authService = AuthService()
    private let userRepository = UserRepository()
    private let topupRepository = TopupRepository()
    private let withdrawalRepository = WithdrawalRepository()
    private let paymentService = PaymentService()

    private var realtimeChannel: RealtimeChannelV2?
    private var realtimeReaderTasks: [Task<Void, Never>] = []

    // Track which top-ups have already settled as "success" so we can alert
    // exactly once when a new one lands (via the realtime subscription) without
    // re-alerting for history already on screen at first load.
    private var knownSuccessTopupIds: Set<String> = []
    private var didLoadTopupsOnce = false

    deinit {
        realtimeReaderTasks.forEach { $0.cancel() }
        realtimeReaderTasks.removeAll()
        if let channel = realtimeChannel {
            let client = supabase
            Task {
                await client.removeChannel(channel)
            }
        }
    }

    func start() async {
        await refresh()
        await startRealtimeSubscription()
    }

    func startRealtimeSubscription() async {
        stop()
        guard let session = try? await authService.getCurrentSession() else { return }
        let uid = session.user.id.uuidString.lowercased()

        let channel = supabase.channel("payment-updates-\(uid)")
        self.realtimeChannel = channel

        let topupStream = channel.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "topups",
            filter: "user_id=eq.\(uid)"
        )
        let withdrawalStream = channel.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "withdrawals",
            filter: "user_id=eq.\(uid)"
        )

        realtimeReaderTasks.append(Task { [weak self] in
            guard let self = self else { return }
            await channel.subscribe()

            Task { [weak self] in
                for await _ in topupStream { await self?.refresh() }
            }
            Task { [weak self] in
                for await _ in withdrawalStream { await self?.refresh() }
            }
        })

    }

    func stop() {
        realtimeReaderTasks.forEach { $0.cancel() }
        realtimeReaderTasks.removeAll()
        if let channel = realtimeChannel {
            Task {
                await supabase.removeChannel(channel)
            }
            realtimeChannel = nil
        }
    }

    func refresh() async {
        guard let session = try? await authService.getCurrentSession() else { return }
        let uid = session.user.id.uuidString.lowercased()
        do {
            async let user = userRepository.fetchUser(uid: uid)
            async let topupHistory = topupRepository.fetchTopups(userId: uid)
            async let withdrawalHistory = withdrawalRepository.fetchWithdrawals(userId: uid)

            let fetchedUser = try await user
            self.balance = fetchedUser.balance
            self.heldBalance = fetchedUser.heldBalance ?? 0
            self.bankName = fetchedUser.bankName ?? ""
            self.bankAccountNumber = fetchedUser.bankAccountNumber ?? ""
            self.bankAccountName = fetchedUser.bankAccountName ?? ""

            let fetchedTopups = try await topupHistory
            detectSuccessfulTopups(fetchedTopups)
            self.topups = fetchedTopups
            self.withdrawals = try await withdrawalHistory
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }

    // Surface a "Top up berhasil!" alert the moment a top-up settles to success.
    private func detectSuccessfulTopups(_ fetched: [Topup]) {
        let successIds = Set(
            fetched
                .filter { $0.status.lowercased() == "success" }
                .compactMap { $0.id }
        )
        if didLoadTopupsOnce {
            let newlySettled = successIds.subtracting(knownSuccessTopupIds)
            if !newlySettled.isEmpty {
                self.successMessage = "Top up berhasil! Saldo Anda telah diperbarui."
            }
        }
        knownSuccessTopupIds = successIds
        didLoadTopupsOnce = true
    }

    func startTopup(amount: Int) async {
        guard amount >= minTopupAmount else {
            self.errorMessage = "Minimal top up \(minTopupAmount.rupiah)"
            return
        }
        guard amount <= maxTopupAmount else {
            self.errorMessage = "Maksimal top up \(maxTopupAmount.rupiah)"
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

    func saveBankDetails(bankName: String, accountNumber: String, accountName: String) async -> Bool {
        guard let session = try? await authService.getCurrentSession() else { return false }
        let uid = session.user.id.uuidString.lowercased()
        isLoading = true
        errorMessage = nil
        do {
            let payload = BankDetailsUpdatePayload(
                bank_name: bankName,
                bank_account_number: accountNumber,
                bank_account_name: accountName
            )
            try await userRepository.updateBankDetails(uid: uid, payload: payload)
            await refresh()
            isLoading = false
            successMessage = "Rekening bank tersimpan."
            return true
        } catch {
            self.errorMessage = error.localizedDescription
            isLoading = false
            return false
        }
    }

    func requestWithdrawal(amount: Int) async -> Bool {
        guard amount >= 10000 else {
            self.errorMessage = "Minimal penarikan Rp10.000"
            return false
        }
        guard Double(amount) <= balance else {
            self.errorMessage = "Saldo tidak mencukupi."
            return false
        }
        guard hasBankDetails else {
            self.errorMessage = "Atur rekening bank terlebih dahulu."
            return false
        }
        isLoading = true
        errorMessage = nil
        do {
            try await withdrawalRepository.requestWithdrawal(amount: Double(amount))
            await refresh()
            isLoading = false
            successMessage = "Permintaan penarikan dikirim. Menunggu persetujuan."
            return true
        } catch {
            self.errorMessage = error.localizedDescription
            isLoading = false
            return false
        }
    }

    // Reopen the Snap session for an unfinished (pending) top-up, using the
    // redirect_url stored when it was created. Valid until the link expires.
    func resumeTopup(_ topup: Topup) {
        guard topup.status.lowercased() == "pending",
              let urlString = topup.redirectUrl,
              let url = URL(string: urlString) else { return }
        self.currentOrderId = topup.orderId
        self.paymentTarget = PaymentTarget(url: url)
    }

    // Called when the Midtrans WebView sheet is dismissed. The webhook credits
    // the balance asynchronously; the realtime topups subscription reflects it live.
    func paymentFlowFinished() async {
        currentOrderId = nil
        await refresh()
    }
}
