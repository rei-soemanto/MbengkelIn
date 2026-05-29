//
//  WatchComponents.swift
//  MbengkelInWatchOS Watch App
//
//  Created by Rei Soemanto on 29/05/26.
//

import SwiftUI

// Horizontal 3-segment progress bar — only ever shown when an order is active.
struct WatchProgressBar: View {
    let stage: String
    private var index: Int {
        switch stage { case "inProgress": return 1; case "finished": return 2; default: return 0 }
    }
    private let labels = ["Mencari", "Dikerjakan", "Selesai"]
    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { i in
                    Capsule().fill(i <= index ? Color.green : Color.gray.opacity(0.3)).frame(height: 6)
                }
            }
            HStack {
                ForEach(0..<3, id: \.self) { i in
                    Text(labels[i]).font(.system(size: 9))
                        .fontWeight(i == index ? .bold : .regular)
                        .foregroundStyle(i == index ? Color.primary : Color.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }
}

struct WatchOfferRow: View {
    let offer: WatchBidOffer
    let isWorking: Bool
    let onApprove: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(offer.bengkelName).font(.caption.bold()).lineLimit(1)
                Spacer()
                if let rating = offer.rating, rating > 0 {
                    Label(String(format: "%.1f", rating), systemImage: "star.fill")
                        .font(.system(size: 9)).foregroundStyle(.yellow)
                }
            }
            Text(formatRupiah(offer.price)).font(.headline)
            Button(action: onApprove) { Text("Setujui").frame(maxWidth: .infinity) }
                .buttonStyle(.borderedProminent).tint(.green).disabled(isWorking)
        }
        .padding(8).background(Color.gray.opacity(0.15)).clipShape(RoundedRectangle(cornerRadius: 10))
    }
    private func formatRupiah(_ amount: Int) -> String {
        let f = NumberFormatter(); f.numberStyle = .decimal; f.locale = Locale(identifier: "id_ID")
        return "Rp" + (f.string(from: NSNumber(value: amount)) ?? "\(amount)")
    }
}

// Tappable 1–5 stars. No textfield anywhere (requirement 7).
struct WatchStarRating: View {
    @Binding var rating: Int
    var body: some View {
        HStack(spacing: 4) {
            ForEach(1...5, id: \.self) { i in
                Image(systemName: i <= rating ? "star.fill" : "star")
                    .foregroundStyle(.yellow).font(.title3)
                    .onTapGesture { rating = i }
                    .accessibilityLabel("\(i) bintang")
            }
        }
    }
}

struct RatingSubmitView: View {
    let isWorking: Bool
    let onSubmit: (Int) -> Void
    @State private var rating: Int = 0
    var body: some View {
        VStack(spacing: 10) {
            Text("Beri penilaian").font(.caption).foregroundStyle(.secondary)
            WatchStarRating(rating: $rating)
            Button { onSubmit(rating) } label: { Text("Kirim Penilaian").frame(maxWidth: .infinity) }
                .buttonStyle(.borderedProminent).disabled(rating == 0 || isWorking)
        }
    }
}

#Preview("Progress") {
    WatchProgressBar(stage: "inProgress")
}

#Preview("Offer") {
    WatchOfferRow(offer: WatchBidOffer(bidId: "1", bengkelName: "Bengkel Jaya", price: 75000, rating: 4.6),
                  isWorking: false, onApprove: {})
}

#Preview("Rating") {
    RatingSubmitView(isWorking: false, onSubmit: { _ in })
}
