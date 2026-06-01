import SwiftUI

struct OrderRequestCard: View {
    let order: NearbyOrder
    let pendingBid: Bid?
    let onBid: () -> Void
    // Fired once when the customer's 2-minute request window elapses.
    var onExpire: (() -> Void)? = nil
    // True when our previous offer on this order was declined by the customer.
    var wasRejected: Bool = false

    private var priceLabel: String { order.price.map { "Rp\($0)" } ?? "-" }
    private var isTireService: Bool {
        (order.serviceType ?? order.description ?? "").lowercased().contains("ban")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            if order.isEmergency == true { emergencyBadge }
            serviceChip
            if let info = order.vehicleInfo, !info.isEmpty {
                Label(info, systemImage: "car.fill")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            detailRow
            OrderCountdownBar(createdAt: order.createdAt, onExpire: onExpire)
            if wasRejected && pendingBid == nil { deniedNote }
            bottomRow
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 2)
    }

    private var header: some View {
        HStack {
            Text(order.customerName ?? "Pelanggan")
                .font(.headline).fontWeight(.bold)
            Spacer()
            DistanceBadge(meters: order.distanceM ?? 0)
        }
    }

    private var emergencyBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "exclamationmark.triangle.fill")
            Text("Darurat")
        }
        .font(.caption).fontWeight(.semibold).foregroundColor(.red)
    }

    private var serviceChip: some View {
        HStack(spacing: 6) {
            Image(systemName: ServiceType(rawValue: order.serviceType ?? "")?.iconName ?? "wrench.and.screwdriver.fill")
                .font(.caption).foregroundColor(.white)
                .padding(5).background(Color.primary).clipShape(Circle())
            Text(order.description ?? order.serviceType ?? "Permintaan servis")
                .font(.subheadline).fontWeight(.bold).foregroundColor(.primary)
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(Color.primary.opacity(0.08)).cornerRadius(8)
    }

    private var photoUrls: [String] { order.photoUrls ?? [] }

    @ViewBuilder
    private var detailRow: some View {
        if isTireService || !photoUrls.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                if isTireService, let count = order.tireCount {
                    Label("\(count) ban", systemImage: "circle.dashed")
                        .font(.subheadline).fontWeight(.semibold).foregroundColor(.primary)
                }
                if !photoUrls.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(photoUrls, id: \.self) { url in
                                OrderPhotoThumbnail(photoUrl: url)
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var deniedNote: some View {
        HStack(spacing: 6) {
            Image(systemName: "xmark.circle.fill")
            Text("Tawaran sebelumnya ditolak. Ajukan harga lain.")
        }
        .font(.caption).fontWeight(.semibold).foregroundColor(.red)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10).padding(.vertical, 8)
        .background(Color.red.opacity(0.08)).cornerRadius(8)
    }

    private var bottomRow: some View {
        HStack {
            Text(priceLabel).font(.headline).fontWeight(.bold)
            Spacer()
            if pendingBid != nil {
                HStack(spacing: 6) {
                    Image(systemName: "paperplane.fill")
                    Text("Tawaran terkirim")
                }
                .font(.subheadline).fontWeight(.semibold).foregroundColor(.secondary)
            } else {
                Button(action: onBid) {
                    Text(wasRejected ? "Tawar Lagi" : "Tawar")
                        .font(.subheadline).fontWeight(.bold)
                        .foregroundColor(Color(.systemBackground))
                        .padding(.horizontal, 20).padding(.vertical, 10)
                        .background(Color.primary.opacity(0.9)).cornerRadius(12)
                }
            }
        }
    }
}
