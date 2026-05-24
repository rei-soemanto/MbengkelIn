import SwiftUI
import Combine

struct BidReceivedCard: View {
    let bid: Bid
    let onAccept: () -> Void
    let onReject: () -> Void
    var onAutoReject: (() -> Void)? = nil

    @State private var timeRemaining: TimeInterval = 120
    @State private var hasAutoRejected: Bool = false
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var statusColor: Color {
        switch bid.status {
        case "Accepted": return .green
        case "Rejected": return .red
        default: return .orange
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Workshop Profile Section
            HStack(alignment: .top, spacing: 12) {
                // Avatar / Icon
                Image(systemName: "wrench.and.screwdriver.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.white)
                    .padding(12)
                    .background(Color.primary.opacity(0.85))
                    .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(bid.bengkel?.name ?? "Mekanik Terdekat")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    if let rating = bid.bengkel?.averageRating, rating > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .foregroundColor(.amber)
                                .font(.caption)
                            Text(String(format: "%.1f", rating))
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Text("(\(bid.bengkel?.totalReviews ?? 0) ulasan)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Text("Baru terdaftar")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Bid Price
                VStack(alignment: .trailing, spacing: 4) {
                    Text(formatToRupiah(bid.price))
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    HStack(spacing: 6) {
                        if bid.status == "Pending" && timeRemaining > 0 {
                            HStack(spacing: 3) {
                                Image(systemName: "timer")
                                Text(formatTimeRemaining())
                            }
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.red)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.red.opacity(0.1))
                            .clipShape(Capsule())
                        }
                        
                        Text(bid.status)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(statusColor)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(statusColor.opacity(0.12))
                            .clipShape(Capsule())
                    }
                }
            }
            
            // Notes Section
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
            
            // Actions Section
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

    private func updateCountdown() {
        guard !hasAutoRejected else { return }
        guard let createdAtStr = bid.createdAt,
              let createdDate = parseDate(createdAtStr) else {
            timeRemaining = 120
            return
        }
        let elapsed = Date().timeIntervalSince(createdDate)
        let remaining = 120 - elapsed
        if remaining <= 0 {
            timeRemaining = 0
            hasAutoRejected = true
            if let autoReject = onAutoReject {
                autoReject()
            } else {
                onReject()
            }
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

    private func formatToRupiah(_ amount: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "IDR"
        formatter.locale = Locale(identifier: "id_ID")
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "Rp 0"
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
        ), onAccept: {}, onReject: {})
        .padding()
    }
    .background(Color(.systemGroupedBackground))
}
