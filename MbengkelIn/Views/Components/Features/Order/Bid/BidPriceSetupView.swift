//
//  BidPriceSetupView.swift
//  MbengkelIn
//
//  Created by Bryan Fernando Dinata on 19/05/26.
//

import SwiftUI

struct BidPriceSetupView: View {
    let serviceType: ServiceType
    let minPrice: Int
    let initialPrice: Int
    let isStartingSearch: Bool
    let onSubmit: (Int) -> Void

    @State private var inputPrice: Int
    @State private var priceText: String
    @State private var showError = false

    init(
        serviceType: ServiceType,
        minPrice: Int,
        initialPrice: Int,
        isStartingSearch: Bool,
        onSubmit: @escaping (Int) -> Void
    ) {
        self.serviceType = serviceType
        self.minPrice = minPrice
        self.initialPrice = initialPrice
        self.isStartingSearch = isStartingSearch
        self.onSubmit = onSubmit
        _inputPrice = State(initialValue: initialPrice)
        _priceText = State(initialValue: "\(initialPrice)")
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                infoCard
                inputCard
                quickSelect
                Spacer(minLength: 40)
                submitButton
            }
            .padding()
        }
        .alert(isPresented: $showError) {
            Alert(
                title: Text("Harga Tidak Valid"),
                message: Text("Harga penawaran harus minimal Rp\(minPrice)."),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    private var infoCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: serviceType.iconName)
                    .font(.title2)
                    .foregroundColor(.white)
                    .padding(12)
                    .background(Color.primary)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(serviceType.rawValue)
                        .font(.title3)
                        .fontWeight(.bold)
                    Text("Pemberian penawaran harga awal")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                Text("Harga Minimum Sistem")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                Text(Rupiah.format(minPrice))
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 4)
    }

    private var inputCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Tentukan Harga Tawaran Anda")
                .font(.headline)

            HStack {
                Text("Rp")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)

                TextField("0", text: $priceText)
                    .font(.system(size: 32, weight: .bold))
                    .keyboardType(.numberPad)
                    .onChange(of: priceText) { newValue in
                        let filtered = newValue.filter { "0123456789".contains($0) }
                        if let parsed = Int(filtered) {
                            inputPrice = parsed
                        } else if filtered.isEmpty {
                            inputPrice = 0
                        }
                    }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)

            Text("Bengkel akan menawarkan jasanya berdasarkan harga awal yang Anda tentukan. Semakin bersaing harga Anda, semakin cepat bengkel merespons.")
                .font(.caption)
                .foregroundColor(.secondary)
                .lineSpacing(4)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 4)
    }

    private var quickSelect: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Pilihan Cepat")
                .font(.subheadline)
                .foregroundColor(.secondary)

            HStack(spacing: 12) {
                ForEach([minPrice, minPrice + 25000, minPrice + 50000], id: \.self) { priceOption in
                    Button(action: {
                        inputPrice = priceOption
                        priceText = "\(priceOption)"
                    }) {
                        Text(Rupiah.format(priceOption))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(inputPrice == priceOption ? .white : .primary)
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity)
                            .background(inputPrice == priceOption ? Color.primary : Color(.systemBackground))
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.primary.opacity(0.2), lineWidth: inputPrice == priceOption ? 0 : 1)
                            )
                    }
                }
            }
        }
    }

    private var submitButton: some View {
        Button(action: {
            if inputPrice < minPrice {
                showError = true
            } else {
                onSubmit(inputPrice)
            }
        }) {
            HStack {
                Image(systemName: serviceType.iconName)
                Text("Temukan Bengkel")
                    .fontWeight(.bold)
            }
            .foregroundColor(Color(.systemBackground))
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(Color.primary.opacity(inputPrice >= minPrice ? 0.9 : 0.5))
            .cornerRadius(14)
        }
        .disabled(isStartingSearch)
    }
}
