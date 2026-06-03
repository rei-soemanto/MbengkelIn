//
//  ContentView.swift
//  MbengkelInWatchOS Watch App
//
//  Created by Rei Soemanto on 29/05/26.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var client: WatchConnectivityClient
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if client.state.hasActiveOrder { activeOrderView } else { emptyState }
        }
        .onAppear { client.requestState() }
        .onChange(of: scenePhase) { phase in
            if phase == .active { client.requestState() }
        }
    }

    private var emptyState: some View {
        ScrollView {
            VStack(spacing: 12) {
                Image(systemName: "wrench.and.screwdriver")
                    .font(.system(size: 28)).foregroundStyle(.secondary)
                Text("Tidak ada pesanan sedang berjalan. Lakukan pemesanan pada aplikasi iPhone.")
                    .font(.footnote).multilineTextAlignment(.center).foregroundStyle(.secondary)
            }
            .padding()
        }
    }

    private var activeOrderView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                WatchProgressBar(stage: client.state.stage)
                stageContent
            }
            .padding(.horizontal, 6).padding(.vertical, 4)
        }
    }

    @ViewBuilder private var stageContent: some View {
        switch client.state.stage {
        case "finding": findingContent
        case "inProgress": inProgressContent
        case "finished": finishedContent
        default: EmptyView()
        }
    }

    private var findingContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Mencari Bengkel").font(.headline)
            if client.state.offers.isEmpty {
                HStack(spacing: 6) {
                    ProgressView()
                    Text("Menunggu tawaran...").font(.caption).foregroundStyle(.secondary)
                }
            } else {
                ForEach(client.state.offers) { offer in
                    WatchOfferRow(offer: offer, isWorking: client.isWorking) { client.approve(bidId: offer.bidId) }
                }
            }
        }
    }

    private var inProgressContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Sedang Dikerjakan").font(.headline)
            if let name = client.state.bengkelName {
                Label(name, systemImage: "wrench.and.screwdriver.fill").font(.caption).lineLimit(1)
            }
            if let price = client.state.agreedPrice {
                Text(formatRupiah(price)).font(.title3.bold())
            }
            if client.state.mySideCompleted {
                Label("Menunggu konfirmasi pihak lain", systemImage: "clock.fill")
                    .font(.caption).foregroundStyle(.orange)
            } else if !client.state.canFinish {
                Label("Menunggu bengkel tiba di lokasi", systemImage: "location.circle")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                Button { client.finishJob() } label: {
                    Label("Selesaikan Pesanan", systemImage: "checkmark.circle.fill").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent).tint(.green).disabled(client.isWorking)
            }
        }
    }

    private var finishedContent: some View {
        VStack(spacing: 10) {
            Image(systemName: "checkmark.seal.fill").font(.title).foregroundStyle(.green)
            Text("Pesanan Selesai").font(.headline)
            if client.state.alreadyRated {
                Text("Terima kasih atas penilaian Anda.")
                    .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
            } else {
                RatingSubmitView(isWorking: client.isWorking) { client.submitRating($0) }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func formatRupiah(_ amount: Int) -> String {
        let f = NumberFormatter(); f.numberStyle = .decimal; f.locale = Locale(identifier: "id_ID")
        return "Rp" + (f.string(from: NSNumber(value: amount)) ?? "\(amount)")
    }
}

#Preview {
    ContentView().environmentObject(WatchConnectivityClient.shared)
}
