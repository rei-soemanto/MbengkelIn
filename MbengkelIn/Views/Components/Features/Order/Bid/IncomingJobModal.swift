import SwiftUI

// In-app modal that pops for a bengkel when a brand-new nearby order arrives.
struct IncomingJobModal: View {
    let order: NearbyOrder
    let onBid: () -> Void
    let onDismiss: () -> Void

    private var priceLabel: String {
        if let price = order.price { return "Rp\(price)" }
        return "-"
    }

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "bell.badge.fill")
                .font(.system(size: 44))
                .foregroundColor(.orange)
                .padding(.top, 28)

            Text("Order Baru Masuk!")
                .font(.title2)
                .fontWeight(.bold)

            VStack(spacing: 8) {
                Text(order.description ?? order.serviceType ?? "Permintaan servis")
                    .font(.headline)
                    .multilineTextAlignment(.center)

                if let info = order.vehicleInfo, !info.isEmpty {
                    Label(info, systemImage: "car.fill")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                HStack(spacing: 6) {
                    Image(systemName: "location.fill")
                    Text(String(format: "%.0f m", order.distanceM ?? 0))
                    Text("•")
                    Text("Harga pelanggan \(priceLabel)")
                }
                .font(.subheadline)
                .foregroundColor(.secondary)
            }

            Spacer()

            VStack(spacing: 12) {
                PrimaryButton(title: "Beri Tawaran", iconName: "paperplane.fill", action: onBid)

                Button(action: onDismiss) {
                    Text("Nanti")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    IncomingJobModal(
        order: NearbyOrder(
            id: "1",
            customerId: "c1",
            customerName: "Budi",
            serviceType: "Ban Pecah",
            description: "Ban pecah di tol",
            isEmergency: true,
            latitude: 0,
            longitude: 0,
            price: 80000,
            status: "To Do",
            createdAt: nil,
            distanceM: 1200
        ),
        onBid: {},
        onDismiss: {}
    )
}
