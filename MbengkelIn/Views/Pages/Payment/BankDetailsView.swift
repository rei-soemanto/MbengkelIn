//
//  BankDetailsView.swift
//  MbengkelIn
//
//  Created by Amadeus Eugine Dirgantara on 29/05/26.
//

import SwiftUI

struct BankDetailsView: View {
    @ObservedObject var viewModel: PaymentViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var selectedBank: IndonesianBank?
    @State private var accountNumber: String = ""
    @State private var accountName: String = ""

    private var accountNumberError: String? {
        guard let bank = selectedBank, !accountNumber.isEmpty else { return nil }
        if !accountNumber.allSatisfy({ $0.isNumber }) {
            return "Nomor rekening hanya boleh angka."
        }
        if !bank.accountLengths.contains(accountNumber.count) {
            return "Nomor rekening \(bank.name) harus \(bank.lengthDescription) (saat ini \(accountNumber.count))."
        }
        return nil
    }

    private var isValid: Bool {
        guard let bank = selectedBank else { return false }
        return bank.isValidAccountNumber(accountNumber)
            && !accountName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Rekening Bank") {
                    Picker("Bank", selection: $selectedBank) {
                        Text("Pilih Bank").tag(IndonesianBank?.none)
                        ForEach(IndonesianBank.all) { bank in
                            Text(bank.name).tag(IndonesianBank?.some(bank))
                        }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        TextField("Nomor Rekening", text: $accountNumber)
                            .keyboardType(.numberPad)
                            .onChange(of: accountNumber) { _, newValue in
                                let digits = String(newValue.filter { $0.isNumber })
                                if digits != newValue { accountNumber = digits }
                            }
                        if let bank = selectedBank {
                            Text(accountNumberError ?? "Format \(bank.name): \(bank.lengthDescription).")
                                .font(.caption)
                                .foregroundColor(accountNumberError == nil ? .secondary : .red)
                        } else {
                            Text("Pilih bank terlebih dahulu.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    TextField("Nama Pemilik Rekening", text: $accountName)
                        .textInputAutocapitalization(.words)
                }
            }
            .navigationTitle("Rekening Bank")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Batal") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Simpan") {
                        Task {
                            guard let bank = selectedBank else { return }
                            let ok = await viewModel.saveBankDetails(
                                bankName: bank.name,
                                accountNumber: accountNumber,
                                accountName: accountName.trimmingCharacters(in: .whitespaces)
                            )
                            if ok { dismiss() }
                        }
                    }
                    .disabled(!isValid)
                }
            }
            .onAppear {
                selectedBank = IndonesianBank.named(viewModel.bankName)
                accountNumber = viewModel.bankAccountNumber
                accountName = viewModel.bankAccountName
            }
        }
    }
}
