//
//  WithdrawView.swift
//  MbengkelIn
//
//  Created by Amadeus Eugine Dirgantara on 29/05/26.
//

import SwiftUI

struct WithdrawView: View {
    @ObservedObject var viewModel: PaymentViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var amountText: String = ""

    private var amount: Int { Int(amountText) ?? 0 }

    private var amountError: String? {
        if amountText.isEmpty || amount == 0 { return nil }
        if amount < 10000 { return "Minimal penarikan Rp10.000." }
        if Double(amount) > viewModel.availableBalance { return "Jumlah melebihi saldo." }
        return nil
    }

    private var isValid: Bool {
        amount >= 10000 && Double(amount) <= viewModel.availableBalance && viewModel.hasBankDetails
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Saldo tersedia")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text(Int(viewModel.availableBalance).rupiah)
                            .font(.title2).fontWeight(.bold)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Rekening Tujuan").font(.headline)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(viewModel.bankName) — \(viewModel.bankAccountName)")
                                .font(.subheadline)
                            Text(viewModel.bankAccountNumber)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Jumlah Penarikan").font(.headline)
                            Spacer()
                            Button("Tarik semua") {
                                amountText = "\(Int(viewModel.availableBalance))"
                            }
                            .font(.caption)
                            .disabled(viewModel.availableBalance < 10000)
                        }
                        HStack {
                            Text("Rp").foregroundColor(.secondary)
                            TextField("0", text: $amountText)
                                .keyboardType(.numberPad)
                                .onChange(of: amountText) { _, newValue in
                                    let digits = String(newValue.filter { $0.isNumber })
                                    if digits != newValue { amountText = digits }
                                }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        if let amountError {
                            Text(amountError)
                                .font(.caption).foregroundColor(.red)
                        }
                    }

                    Button {
                        Task {
                            let ok = await viewModel.requestWithdrawal(amount: amount)
                            if ok { dismiss() }
                        }
                    } label: {
                        Text("Ajukan Penarikan")
                            .font(.headline)
                            .foregroundColor(Color(.systemBackground))
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.primary.opacity(isValid ? 0.9 : 0.3))
                            .cornerRadius(16)
                    }
                    .disabled(!isValid)

                    Text("Penarikan akan diproses setelah disetujui admin.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
            }
            .navigationTitle("Tarik Saldo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Batal") { dismiss() }
                }
            }
        }
    }
}
