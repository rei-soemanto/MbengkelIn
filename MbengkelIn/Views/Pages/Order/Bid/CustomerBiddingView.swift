import SwiftUI
import CoreLocation

struct CustomerBiddingView: View {
    @StateObject private var viewModel: CustomerBiddingViewModel

    init(serviceRequestId: String, coordinate: CLLocationCoordinate2D) {
        _viewModel = StateObject(wrappedValue: CustomerBiddingViewModel(
            serviceRequestId: serviceRequestId,
            latitude: coordinate.latitude,
            longitude: coordinate.longitude
        ))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if viewModel.isLoading && viewModel.mechanics.isEmpty && viewModel.bids.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 60)
                } else if viewModel.mechanics.isEmpty && viewModel.bids.isEmpty {
                    BiddingEmptyState(
                        icon: "person.2.slash",
                        title: "Belum ada mekanik",
                        subtitle: "Tunggu sebentar atau tarik untuk menyegarkan."
                    )
                } else {
                    if !viewModel.bids.isEmpty {
                        bidsSection
                    }
                    if !viewModel.mechanics.isEmpty {
                        mechanicsSection
                    }
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Pilih Mekanik")
        .refreshable { await viewModel.refresh() }
        .task { await viewModel.refresh() }
    }

    private var bidsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tawaran masuk")
                .font(.title2)
                .fontWeight(.bold)
            ForEach(viewModel.bids) { bid in
                BidReceivedCard(bid: bid) {
                    Task { await viewModel.acceptBid(bid) }
                }
            }
        }
    }

    private var mechanicsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Mekanik terdekat")
                .font(.title2)
                .fontWeight(.bold)
            ForEach(viewModel.mechanics) { mechanic in
                MechanicCard(mechanic: mechanic)
            }
        }
    }
}

#Preview {
    NavigationStack {
        CustomerBiddingView(
            serviceRequestId: "preview",
            coordinate: CLLocationCoordinate2D(latitude: -7.28, longitude: 112.63)
        )
    }
}
