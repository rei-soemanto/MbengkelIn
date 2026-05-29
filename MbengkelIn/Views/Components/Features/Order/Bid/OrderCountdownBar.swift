import SwiftUI
import Combine

struct OrderCountdownBar: View {
    let createdAt: String?
    var onExpire: (() -> Void)? = nil

    private let windowSeconds: TimeInterval = 120
    @State private var timeRemaining: TimeInterval = 120
    @State private var hasExpired = false
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var isUrgent: Bool { timeRemaining <= 30 }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "hourglass")
            Text("Sisa waktu menanggapi")
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
        .onAppear { updateCountdown() }
        .onReceive(timer) { _ in updateCountdown() }
    }

    private func updateCountdown() {
        guard !hasExpired else { return }
        guard let createdAtStr = createdAt,
              let createdDate = parseDate(createdAtStr) else {
            timeRemaining = windowSeconds
            return
        }
        let remaining = windowSeconds - Date().timeIntervalSince(createdDate)
        if remaining <= 0 {
            timeRemaining = 0
            hasExpired = true
            onExpire?()
        } else {
            timeRemaining = remaining
        }
    }

    private func formatTimeRemaining() -> String {
        let total = max(0, Int(timeRemaining))
        return String(format: "%02d:%02d", total / 60, total % 60)
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
