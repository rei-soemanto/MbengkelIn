import SwiftUI

extension Int {
    var rupiah: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = "."
        return "Rp" + (formatter.string(from: NSNumber(value: self)) ?? "\(self)")
    }
}

struct PaymentView: View {
    @StateObject private var viewModel = PaymentViewModel()
    @State private var customAmount: String = ""

    private var enteredAmount: Int { Int(customAmount) ?? 0 }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    balanceCard
                    topUpSection
                    historySection
                }
                .padding()
            }
            .background(Color(.systemBackground))
            .navigationTitle("Pembayaran")
            .task { await viewModel.start() }
            .onDisappear { viewModel.stop() }
            .refreshable { await viewModel.refresh() }
            .sheet(item: $viewModel.paymentTarget) { target in
                MidtransPaymentSheet(url: target.url) {
                    Task { await viewModel.paymentFlowFinished() }
                }
            }
            .loadingOverlay(phase: viewModel.isLoading ? .loading(message: "Memproses...") : .idle)
            .alert("Terjadi Kesalahan", isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { viewModel.errorMessage = nil }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }

    private var balanceCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Saldo Anda")
                .font(.subheadline)
                .foregroundColor(Color(.systemBackground).opacity(0.8))
            Text(Int(viewModel.balance).rupiah)
                .font(.system(size: 36, weight: .bold))
                .foregroundColor(Color(.systemBackground))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24)
        .background(Color.primary.opacity(0.9))
        .cornerRadius(20)
    }

    private var topUpSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Top Up Saldo").font(.headline)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(viewModel.presetAmounts, id: \.self) { amount in
                    Button {
                        customAmount = "\(amount)"
                    } label: {
                        Text(amount.rupiah)
                            .font(.subheadline).fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color(.systemGray6))
                            .foregroundColor(.primary)
                            .cornerRadius(12)
                    }
                }
            }

            HStack {
                Text("Rp").foregroundColor(.secondary)
                TextField("Nominal lain", text: $customAmount)
                    .keyboardType(.numberPad)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)

            Button {
                Task { await viewModel.startTopup(amount: enteredAmount) }
            } label: {
                Text("Top Up Sekarang")
                    .font(.headline)
                    .foregroundColor(Color(.systemBackground))
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.primary.opacity(enteredAmount >= 10000 ? 0.9 : 0.3))
                    .cornerRadius(16)
            }
            .disabled(enteredAmount < 10000)
        }
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Riwayat Top Up").font(.headline)
            if viewModel.topups.isEmpty {
                Text("Belum ada riwayat top up.")
                    .foregroundColor(.secondary)
                    .font(.subheadline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
            } else {
                ForEach(viewModel.topups) { topup in
                    if topup.status.lowercased() == "pending", topup.redirectUrl != nil {
                        Button {
                            viewModel.resumeTopup(topup)
                        } label: {
                            TopupHistoryRow(topup: topup)
                        }
                        .buttonStyle(.plain)
                    } else {
                        TopupHistoryRow(topup: topup)
                    }
                }
            }
        }
    }
}

struct MidtransPaymentSheet: View {
    let url: URL
    let onFinish: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            MidtransWebView(url: url) {
                dismiss()
            }
            .ignoresSafeArea(edges: .bottom)
            .navigationTitle("Pembayaran")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Tutup") { dismiss() }
                }
            }
        }
        .onDisappear { onFinish() }
    }
}

#Preview {
    PaymentView()
}
