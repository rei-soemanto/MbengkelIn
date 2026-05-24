import SwiftUI
import Combine

struct OrderRequestCard: View {
    let order: NearbyOrder
    let pendingBid: Bid?
    let onBid: () -> Void
    var onAutoReject: (() -> Void)? = nil

    @State private var timeRemaining: TimeInterval = 120
    @State private var hasAutoRejected: Bool = false
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var priceLabel: String {
        if let price = order.price {
            return "Rp\(price)"
        }
        return "-"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(order.customerName ?? "Pelanggan")
                    .font(.headline)
                    .fontWeight(.bold)
                Spacer()
                DistanceBadge(meters: order.distanceM ?? 0)
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

            HStack(spacing: 6) {
                Image(systemName: "wrench.and.screwdriver.fill")
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(5)
                    .background(Color.primary)
                    .clipShape(Circle())
                
                Text(order.description ?? order.serviceType ?? "Permintaan servis")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.primary.opacity(0.08))
            .cornerRadius(8)

            HStack {
                Text(priceLabel)
                    .font(.headline)
                    .fontWeight(.bold)
                Spacer()
                
                if let _ = pendingBid {
                    // Show Countdown Timer
                    HStack(spacing: 6) {
                        Image(systemName: "hourglass.badge.plus")
                        Text(formatTimeRemaining())
                    }
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.red)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(12)
                } else {
                    // Show Bid Button
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
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 2)
        .onAppear {
            if pendingBid != nil {
                updateCountdown()
            }
        }
        .onReceive(timer) { _ in
            if pendingBid != nil {
                updateCountdown()
            }
        }
    }

    private func updateCountdown() {
        guard !hasAutoRejected else { return }
        guard let bid = pendingBid,
              let createdAtStr = bid.createdAt,
              let createdDate = parseDate(createdAtStr) else {
            timeRemaining = 120
            return
        }
        let elapsed = Date().timeIntervalSince(createdDate)
        let remaining = 120 - elapsed
        if remaining <= 0 {
            timeRemaining = 0
            hasAutoRejected = true
            onAutoReject?()
        } else {
            timeRemaining = remaining
        }
    }

    private func formatTimeRemaining() -> String {
        let minutes = Int(timeRemaining) / 60
        let seconds = Int(timeRemaining) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private func parseDate(_ dateString: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: dateString) {
            return date
        }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: dateString)
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
    ), pendingBid: nil, onBid: {})
    .padding()
}
