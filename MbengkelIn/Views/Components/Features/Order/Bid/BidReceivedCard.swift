import SwiftUI
import Combine
import CoreLocation

struct BidReceivedCard: View {
    let bid: Bid
    // Customer's order location, used to show how far each bengkel is.
    var customerCoordinate: CLLocationCoordinate2D? = nil
    let onAccept: () -> Void
    let onReject: () -> Void
    // Fired once when this offer's response window elapses (timeout, not a loss).
    var onExpire: (() -> Void)? = nil

    @State private var timeRemaining: TimeInterval = 120
    @State private var hasExpired: Bool = false
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var statusColor: Color {
        switch bid.status {
        case "Accepted": return .green
        case "Rejected", "Expired", "AutoRejected": return .red
        default: return .orange
        }
    }

    // Straight-line distance from the customer to this bengkel, if known.
    private var distanceMeters: Double? {
        guard let customer = customerCoordinate,
              let lat = bid.bengkel?.latitude,
              let lon = bid.bengkel?.longitude else { return nil }
        let from = CLLocation(latitude: customer.latitude, longitude: customer.longitude)
        let to = CLLocation(latitude: lat, longitude: lon)
        return from.distance(from: to)
    }

    private var isUrgent: Bool { timeRemaining <= 30 }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Workshop profile + price
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "wrench.and.screwdriver.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.white)
                    .padding(12)
                    .background(Color.primary.opacity(0.85))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 6) {
                    Text(bid.bengkel?.name ?? "Bengkel Terdekat")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)

                    HStack(spacing: 10) {
                        if let rating = bid.bengkel?.averageRating, rating > 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "star.fill")
                                    .foregroundColor(.amber)
                                    .font(.caption)
                                Text(String(format: "%.1f", rating))
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                Text("(\(bid.bengkel?.totalReviews ?? 0))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        } else {
                            Text("Baru terdaftar")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        if let meters = distanceMeters {
                            DistanceBadge(meters: meters)
                        }
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(Rupiah.format(bid.price))
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)

                    Text(statusLabel)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(statusColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(statusColor.opacity(0.12))
                        .clipShape(Capsule())
                }
            }

            // Countdown on its own full-width row so it never gets squeezed.
            if bid.status == "Pending" && timeRemaining > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "timer")
                    Text("Berakhir dalam")
                        .font(.caption)
                    Spacer()
                    Text(formatTimeRemaining())
                        .font(.subheadline.monospacedDigit())
                        .fontWeight(.bold)
                }
                .foregroundColor(isUrgent ? .red : .secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background((isUrgent ? Color.red : Color.primary).opacity(0.08))
                .cornerRadius(10)
            }

            // Notes
            if let notes = bid.notes, !notes.isEmpty {
                Text(notes)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
            }

            // Actions
            if bid.status == "Pending" {
                HStack(spacing: 12) {
                    Button(action: onReject) {
                        Text("Tolak")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(12)
                    }

                    Button(action: onAccept) {
                        Text("Terima")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(Color(.systemBackground))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.primary.opacity(0.9))
                            .cornerRadius(12)
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
        .onAppear {
            if bid.status == "Pending" {
                updateCountdown()
            }
        }
        .onReceive(timer) { _ in
            if bid.status == "Pending" {
                updateCountdown()
            }
        }
    }

    private var statusLabel: String {
        switch bid.status {
        case "Pending": return "Menunggu"
        case "Accepted": return "Diterima"
        case "Rejected": return "Ditolak"
        case "Expired": return "Kedaluwarsa"
        case "AutoRejected": return "Kedaluwarsa"
        default: return bid.status
        }
    }

    private func updateCountdown() {
        guard !hasExpired else { return }
        guard let createdAtStr = bid.createdAt,
              let createdDate = parseDate(createdAtStr) else {
            timeRemaining = 120
            return
        }
        let elapsed = Date().timeIntervalSince(createdDate)
        let remaining = 120 - elapsed
        if remaining <= 0 {
            timeRemaining = 0
            hasExpired = true
            onExpire?()
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

// Custom amber color extension for star
extension Color {
    static let amber = Color(red: 245/255, green: 158/255, blue: 11/255)
}

#Preview {
    VStack(spacing: 16) {
        BidReceivedCard(bid: Bid(
            id: "1",
            serviceRequestId: "s1",
            providerUid: "u1",
            bengkelId: "b1",
            price: 120000,
            notes: "Bisa langsung datang dalam 10 menit membawa peralatan ban bocor lengkap.",
            status: "Pending",
            createdAt: nil,
            bengkel: Bengkel(
                id: "b1",
                providerUid: "u1",
                name: "Rei Auto Service",
                address: "Citraland Surabaya",
                latitude: -7.28,
                longitude: 112.63,
                status: "Verified",
                offeredServices: [],
                averageRating: 4.8,
                totalReviews: 24
            )
        ), customerCoordinate: CLLocationCoordinate2D(latitude: -7.30, longitude: 112.65), onAccept: {}, onReject: {})
        .padding()
    }
    .background(Color(.systemGroupedBackground))
}
