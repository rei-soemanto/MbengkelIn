//
//  PaymentView.swift
//  MbengkelIn
//
//  Created by Amadeus Eugine Dirgantara on 29/05/26.
//

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
    @State private var showBankSheet = false
    @State private var showWithdrawSheet = false

    private var enteredAmount: Int { Int(customAmount) ?? 0 }
    private var isAmountValid: Bool {
        enteredAmount >= viewModel.minTopupAmount && enteredAmount <= viewModel.maxTopupAmount
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    balanceCard
                    topUpSection
                    withdrawSection
                    historySection
                    withdrawalHistorySection
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
            .sheet(isPresented: $showBankSheet) {
                BankDetailsView(viewModel: viewModel)
            }
            .sheet(isPresented: $showWithdrawSheet) {
                WithdrawView(viewModel: viewModel)
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
            .alert("Berhasil", isPresented: Binding(
                get: { viewModel.successMessage != nil },
                set: { if !$0 { viewModel.successMessage = nil } }
            )) {
                Button("OK", role: .cancel) { viewModel.successMessage = nil }
            } message: {
                Text(viewModel.successMessage ?? "")
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
            if viewModel.heldBalance > 0 {
                HStack(spacing: 12) {
                    Label("Tertahan \(Int(viewModel.heldBalance).rupiah)", systemImage: "lock.fill")
                    Label("Tersedia \(Int(viewModel.availableBalance).rupiah)", systemImage: "checkmark.circle.fill")
                }
                .font(.caption)
                .foregroundColor(Color(.systemBackground).opacity(0.85))
            }
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

            Text("Min \(viewModel.minTopupAmount.rupiah) — Maks \(viewModel.maxTopupAmount.rupiah)")
                .font(.caption)
                .foregroundColor(enteredAmount > viewModel.maxTopupAmount ? .red : .secondary)

            Button {
                Task { await viewModel.startTopup(amount: enteredAmount) }
            } label: {
                Text("Top Up Sekarang")
                    .font(.headline)
                    .foregroundColor(Color(.systemBackground))
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.primary.opacity(isAmountValid ? 0.9 : 0.3))
                    .cornerRadius(16)
            }
            .disabled(!isAmountValid)
        }
    }

    private var withdrawSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Tarik Saldo").font(.headline)

            if viewModel.hasBankDetails {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(viewModel.bankName) — \(viewModel.bankAccountName)")
                        .font(.subheadline)
                    Text(viewModel.bankAccountNumber)
                        .font(.caption).foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)

                HStack(spacing: 12) {
                    Button { showBankSheet = true } label: {
                        Text("Ubah Rekening")
                            .font(.subheadline).fontWeight(.semibold)
                            .frame(maxWidth: .infinity).padding()
                            .background(Color(.systemGray6)).foregroundColor(.primary)
                            .cornerRadius(12)
                    }
                    Button { showWithdrawSheet = true } label: {
                        Text("Tarik Saldo")
                            .font(.subheadline).fontWeight(.semibold)
                            .frame(maxWidth: .infinity).padding()
                            .background(Color.primary.opacity(0.9)).foregroundColor(Color(.systemBackground))
                            .cornerRadius(12)
                    }
                }
            } else {
                Button { showBankSheet = true } label: {
                    Text("Atur Rekening Bank")
                        .font(.headline).foregroundColor(Color(.systemBackground))
                        .frame(maxWidth: .infinity).padding()
                        .background(Color.primary.opacity(0.9)).cornerRadius(16)
                }
            }
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

    private var withdrawalHistorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Riwayat Penarikan").font(.headline)
            if viewModel.withdrawals.isEmpty {
                Text("Belum ada penarikan.")
                    .foregroundColor(.secondary)
                    .font(.subheadline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
            } else {
                ForEach(viewModel.withdrawals) { withdrawal in
                    WithdrawalHistoryRow(withdrawal: withdrawal)
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
