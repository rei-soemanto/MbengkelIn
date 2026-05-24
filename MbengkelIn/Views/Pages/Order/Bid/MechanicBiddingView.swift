import SwiftUI

struct MechanicBiddingView: View {
    @StateObject private var viewModel = MechanicBiddingViewModel()
    @State private var selectedOrder: NearbyOrder?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if viewModel.isLoading && viewModel.orders.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 60)
                } else if viewModel.orders.isEmpty {
                    BiddingEmptyState(
                        icon: "tray",
                        title: "Belum ada order",
                        subtitle: "Order baru di sekitar Anda akan muncul di sini."
                    )
                } else {
                    ForEach(viewModel.orders) { order in
                        let pendingBid = viewModel.myPendingBids.first(where: { $0.serviceRequestId == order.id })
                        OrderRequestCard(
                            order: order,
                            pendingBid: pendingBid,
                            onBid: {
                                selectedOrder = order
                            },
                            onAutoReject: {
                                if let bid = pendingBid {
                                    Task {
                                        await viewModel.rejectBid(bid)
                                    }
                                }
                            }
                        )
                    }
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Order Masuk")
        .refreshable { await viewModel.loadOrders() }
        .task { await viewModel.start() }
        .sheet(item: $selectedOrder) { order in
            PlaceBidSheet { price, notes in
                Task { await viewModel.placeBid(order: order, price: price, notes: notes) }
            }
        }
    }
}

#Preview {
    NavigationStack {
        MechanicBiddingView()
    }
}
