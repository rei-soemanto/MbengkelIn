//
//  BiddingWaitingState.swift
//  MbengkelIn
//
//  Created by Bryan Fernando Dinata on 19/05/26.
//

import SwiftUI

struct BiddingWaitingState: View {
    let isAnimating: Bool

    var body: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 40)

            Circle()
                .stroke(Color.primary.opacity(0.1), lineWidth: 4)
                .frame(width: 80, height: 80)
                .overlay(
                    Image(systemName: "clock.arrow.2.circlepath")
                        .font(.system(size: 32))
                        .foregroundColor(.primary)
                        .rotationEffect(.degrees(isAnimating ? 360 : 0))
                        .animation(.linear(duration: 2).repeatForever(autoreverses: false), value: isAnimating)
                )

            VStack(spacing: 8) {
                Text("Mencari Bengkel Terbaik...")
                    .font(.headline)
                    .fontWeight(.bold)
                Text("Menunggu bengkel terdekat di sekitar 5km memberikan penawaran terbaik mereka. Mohon tunggu sebentar.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            .padding(.horizontal, 24)

            Spacer()
        }
        .padding(.vertical, 40)
    }
}
