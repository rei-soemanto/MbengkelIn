//
//  SearchCountdownBar.swift
//  MbengkelIn
//
//  Created by Bryan Fernando Dinata on 19/05/26.
//

import SwiftUI

struct SearchCountdownBar: View {
    let secondsRemaining: Int
    let progress: Double

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Label("Mencari bengkel...", systemImage: "dot.radiowaves.left.and.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text(timeString(secondsRemaining))
                    .font(.caption.monospacedDigit().bold())
                    .foregroundColor(.primary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(.systemGray5))
                    Capsule()
                        .fill(Color.primary.opacity(0.9))
                        .frame(width: geo.size.width * progress)
                        .animation(.linear(duration: 1), value: progress)
                }
            }
            .frame(height: 8)
        }
        .padding()
        .background(Color(.systemBackground))
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: -2)
    }

    private func timeString(_ seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}
