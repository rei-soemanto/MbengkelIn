import SwiftUI

struct BidReceivedCard: View {
    let bid: Bid
    let onAccept: () -> Void

    private var statusColor: Color {
        switch bid.status {
        case "Accepted": return .green
        case "Rejected": return .red
        default: return .orange
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Rp\(bid.price)")
                    .font(.headline)
                    .fontWeight(.bold)
                Spacer()
                Text(bid.status)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(statusColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(statusColor.opacity(0.15))
                    .clipShape(Capsule())
            }

            if let notes = bid.notes, !notes.isEmpty {
                Text(notes)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            if bid.status == "Pending" {
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
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 2)
    }
}

#Preview {
    BidReceivedCard(bid: Bid(
        id: "1",
        serviceRequestId: "s1",
        providerUid: "u1",
        bengkelId: "b1",
        price: 120000,
        notes: "Bisa langsung datang dalam 10 menit",
        status: "Pending",
        createdAt: nil
    ), onAccept: {})
    .padding()
}
