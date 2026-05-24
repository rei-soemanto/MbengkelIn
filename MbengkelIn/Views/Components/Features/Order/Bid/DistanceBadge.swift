import SwiftUI

struct DistanceBadge: View {
    let meters: Double

    private var label: String {
        if meters < 1000 {
            return "\(Int(meters)) m"
        }
        return String(format: "%.1f km", meters / 1000)
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "location.fill")
                .font(.caption2)
            Text(label)
                .font(.caption)
                .fontWeight(.medium)
        }
        .foregroundColor(.secondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(.systemGray6))
        .clipShape(Capsule())
    }
}

#Preview {
    VStack(spacing: 12) {
        DistanceBadge(meters: 450)
        DistanceBadge(meters: 2400)
    }
}
