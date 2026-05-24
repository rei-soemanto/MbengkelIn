import SwiftUI

struct OrderRequestCard: View {
    let order: NearbyOrder
    let onBid: () -> Void

    private var priceLabel: String {
        if let price = order.price {
            return "Rp\(price)"
        }
        return "-"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(order.customerName)
                    .font(.headline)
                Spacer()
                DistanceBadge(meters: order.distanceM)
            }

            if order.isEmergency == true {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text("Darurat")
                }
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.red)
            }

            Text(order.description ?? order.serviceType ?? "Permintaan servis")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(3)

            HStack {
                Text(priceLabel)
                    .font(.headline)
                    .fontWeight(.bold)
                Spacer()
                Button(action: onBid) {
                    Text("Tawar")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(Color(.systemBackground))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.primary.opacity(0.9))
                        .cornerRadius(12)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 2)
    }
}

#Preview {
    OrderRequestCard(order: NearbyOrder(
        id: "1",
        customerId: "c1",
        customerName: "Budi",
        serviceType: "Engine",
        description: "Mesin mati di tengah jalan",
        isEmergency: true,
        latitude: 0,
        longitude: 0,
        price: 150000,
        status: "To Do",
        createdAt: nil,
        distanceM: 900
    ), onBid: {})
    .padding()
}
