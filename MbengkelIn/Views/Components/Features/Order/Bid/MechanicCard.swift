import SwiftUI

struct MechanicCard: View {
    let mechanic: NearbyMechanic

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(mechanic.name)
                    .font(.headline)
                Spacer()
                DistanceBadge(meters: mechanic.distanceM)
            }

            Text(mechanic.address)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(2)

            HStack(spacing: 6) {
                Image(systemName: "star.fill")
                    .font(.caption)
                    .foregroundColor(.yellow)
                Text(String(format: "%.1f", mechanic.averageRating))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text("(\(mechanic.totalReviews) ulasan)")
                    .font(.caption)
                    .foregroundColor(.secondary)
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
    MechanicCard(mechanic: NearbyMechanic(
        id: "1",
        providerUid: "u1",
        name: "Bengkel Jaya",
        address: "Jl. Merdeka No. 10",
        latitude: 0,
        longitude: 0,
        averageRating: 4.6,
        totalReviews: 128,
        offeredServices: nil,
        distanceM: 1820
    ))
    .padding()
}
