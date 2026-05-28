//
//  HistoryEmptyState.swift
//  MbengkelIn
//
//  Created by Bryan Fernando Dinata on 28/05/26.
//

import SwiftUI

struct HistoryEmptyState: View {
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "clock.badge.questionmark")
                .font(.system(size: 50))
                .foregroundColor(.secondary)
            Text("Belum ada pesanan")
                .font(.title3.bold())
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    HistoryEmptyState(message: "Riwayat pesanan kamu akan muncul di sini.")
}
