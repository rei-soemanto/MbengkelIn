import SwiftUI

struct OfflineView: View {
    var onRetry: () -> Void = {}

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 56))
                .foregroundColor(.secondary)
            Text("Tidak Ada Koneksi")
                .font(.title2)
                .fontWeight(.bold)
            Text("MbengkelIn butuh koneksi internet untuk berfungsi. Periksa koneksimu lalu coba lagi.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button(action: onRetry) {
                Text("Coba Lagi")
                    .font(.headline)
                    .foregroundColor(Color(.systemBackground))
                    .padding(.horizontal, 32)
                    .padding(.vertical, 12)
                    .background(Color.primary.opacity(0.9))
                    .cornerRadius(16)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

#Preview {
    OfflineView()
}
