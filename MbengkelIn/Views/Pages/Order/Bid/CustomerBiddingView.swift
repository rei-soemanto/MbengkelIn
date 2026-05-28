import SwiftUI
import CoreLocation

struct CustomerBiddingView: View {
    @StateObject private var viewModel: CustomerBiddingViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var inputPrice: Int = 0
    @State private var priceText: String = ""
    @State private var showError: Bool = false

    init(serviceType: ServiceType, coordinate: CLLocationCoordinate2D) {
        _viewModel = StateObject(wrappedValue: CustomerBiddingViewModel(
            serviceType: serviceType,
            latitude: coordinate.latitude,
            longitude: coordinate.longitude
        ))
    }

    var body: some View {
        VStack(spacing: 0) {
            if !viewModel.isSearching {
                priceSetupScreen
            } else {
                activeBiddingScreen
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(viewModel.isSearching ? "Mencari Bengkel" : "Atur Tawaran Anda")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            inputPrice = viewModel.customerBidPrice
            priceText = "\(viewModel.customerBidPrice)"
        }
        .onChange(of: viewModel.customerBidPrice) { newPrice in
            inputPrice = newPrice
            priceText = "\(newPrice)"
        }
        .alert(isPresented: $showError) {
            Alert(
                title: Text("Harga Tidak Valid"),
                message: Text("Harga penawaran harus minimal Rp\(viewModel.minPrice)."),
                dismissButton: .default(Text("OK"))
            )
        }
        .navigationDestination(isPresented: Binding(
            get: { viewModel.acceptedBid != nil },
            set: { if !$0 { viewModel.acceptedBid = nil } }
        )) {
            if let bid = viewModel.acceptedBid {
                OrderTrackingView(
                    bid: bid,
                    customerCoordinate: CLLocationCoordinate2D(
                        latitude: viewModel.latitude,
                        longitude: viewModel.longitude
                    )
                )
            }
        }
    }

    // MARK: - Loading Screen
    private var loadingScreen: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Memuat data pesanan...")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Price Setup Screen
    private var priceSetupScreen: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Info Card
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Image(systemName: "wrench.and.screwdriver.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Color.primary)
                            .clipShape(Circle())
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(viewModel.serviceType.rawValue)
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
                        Text(formatToRupiah(viewModel.minPrice))
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(16)
                .shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 4)

                // Input Card
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

                // Quick Select Options
                VStack(alignment: .leading, spacing: 12) {
                    Text("Pilihan Cepat")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 12) {
                        ForEach([viewModel.minPrice, viewModel.minPrice + 25000, viewModel.minPrice + 50000], id: \.self) { priceOption in
                            Button(action: {
                                inputPrice = priceOption
                                priceText = "\(priceOption)"
                            }) {
                                Text(formatToRupiah(priceOption))
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

                Spacer(minLength: 40)
                
                // Submit Button
                Button(action: {
                    if inputPrice < viewModel.minPrice {
                        showError = true
                    } else {
                        Task {
                            await viewModel.startSearch(price: inputPrice)
                        }
                    }
                }) {
                    HStack {
                        Image(systemName: "wrench.and.screwdriver.fill")
                        Text("Temukan Bengkel")
                            .fontWeight(.bold)
                    }
                    .foregroundColor(Color(.systemBackground))
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Color.primary.opacity(inputPrice >= viewModel.minPrice ? 0.9 : 0.5))
                    .cornerRadius(14)
                }
                .disabled(viewModel.isStartingSearch)
            }
            .padding()
        }
    }

    private var activeBiddingScreen: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Tawaran Aktif Anda")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                    Text(formatToRupiah(viewModel.customerBidPrice))
                        .font(.title2)
                        .fontWeight(.bold)
                }
                Spacer()
                
                Button(action: {
                    viewModel.stopRealtimeSubscription()
                    viewModel.isSearching = false
                }) {
                    Text("Ubah Harga")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color(.systemBackground))
                        .cornerRadius(8)
                        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
                }
            }
            .padding()
            .background(Color(.systemBackground))
            
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if viewModel.bids.isEmpty {
                        // Real-time Loading / Waiting State
                        VStack(spacing: 24) {
                            Spacer(minLength: 40)
                            
                            Circle()
                                .stroke(Color.primary.opacity(0.1), lineWidth: 4)
                                .frame(width: 80, height: 80)
                                .overlay(
                                    Image(systemName: "clock.arrow.2.circlepath")
                                        .font(.system(size: 32))
                                        .foregroundColor(.primary)
                                        .rotationEffect(.degrees(viewModel.isLoading ? 360 : 0))
                                        .animation(.linear(duration: 2).repeatForever(autoreverses: false), value: viewModel.isLoading)
                                )
                            
                            VStack(spacing: 8) {
                                Text("Mencari Bengkel Terbaik...")
                                    .font(.headline)
                                    .fontWeight(.bold)
                                Text("Menunggu bengkel terdekat di sekitar 5km memberikan penawaran terbaik mereka. Mohon tunggu sebentar.")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                    .lineSpacing(4)
                            }
                            .padding(.horizontal, 24)
                            
                            Spacer()
                        }
                        .padding(.vertical, 40)
                    } else {
                        // Bids Section
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text("Tawaran Masuk")
                                    .font(.title3)
                                    .fontWeight(.bold)
                                Spacer()
                                Text("\(viewModel.bids.count) Tawaran")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color(.systemGray5))
                                    .cornerRadius(6)
                            }
                            .padding(.horizontal)
                            .padding(.top, 16)
                            
                            ForEach(viewModel.bids) { bid in
                                BidReceivedCard(bid: bid, onAccept: {
                                    Task { await viewModel.acceptBid(bid) }
                                }, onReject: {
                                    Task { await viewModel.rejectBid(bid) }
                                }, onAutoReject: {
                                    Task { await viewModel.autoRejectBid(bid) }
                                })
                                .padding(.horizontal)
                            }
                        }
                    }
                }
            }
            .refreshable {
                await viewModel.refresh()
            }
        }
    }

    private func formatToRupiah(_ amount: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "IDR"
        formatter.locale = Locale(identifier: "id_ID")
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "Rp 0"
    }
}
