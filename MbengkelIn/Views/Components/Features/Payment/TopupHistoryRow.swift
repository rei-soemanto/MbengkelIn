import SwiftUI

struct TopupHistoryRow: View {
    let topup: Topup

    private var isResumable: Bool {
        topup.status.lowercased() == "pending" && topup.redirectUrl != nil
    }

    private var statusColor: Color {
        switch topup.status.lowercased() {
        case "success": return .green
        case "pending": return .orange
        default: return .red
        }
    }

    private var statusLabel: String {
        switch topup.status.lowercased() {
        case "success": return "Berhasil"
        case "pending": return "Menunggu"
        case "failed": return "Gagal"
        case "expired": return "Kedaluwarsa"
        case "cancelled": return "Dibatalkan"
        default: return topup.status
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "arrow.down.circle.fill")
                .font(.title2)
                .foregroundColor(statusColor)

            VStack(alignment: .leading, spacing: 4) {
                Text(Int(topup.grossAmount).rupiah)
                    .font(.headline)
                if isResumable {
                    Text("Ketuk untuk lanjutkan pembayaran")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else if let date = topup.createdAt {
                    Text(date.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Text(statusLabel)
                .font(.caption)
                .fontWeight(.semibold)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(statusColor.opacity(0.15))
                .foregroundColor(statusColor)
                .clipShape(Capsule())

            if isResumable {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}
