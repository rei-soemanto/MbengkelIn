import SwiftUI

struct WithdrawalHistoryRow: View {
    let withdrawal: Withdrawal

    private var statusColor: Color {
        switch withdrawal.status.lowercased() {
        case "paid", "approved": return .green
        case "pending": return .orange
        default: return .red
        }
    }

    private var statusLabel: String {
        switch withdrawal.status.lowercased() {
        case "pending": return "Menunggu"
        case "approved": return "Disetujui"
        case "paid": return "Dibayar"
        case "rejected": return "Ditolak"
        default: return withdrawal.status
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "arrow.up.circle.fill")
                .font(.title2)
                .foregroundColor(statusColor)

            VStack(alignment: .leading, spacing: 4) {
                Text(Int(withdrawal.amount).rupiah)
                    .font(.headline)
                if let bank = withdrawal.bankName, !bank.isEmpty {
                    Text("\(bank) · \(withdrawal.bankAccountNumber ?? "")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else if let date = withdrawal.createdAt {
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
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}
