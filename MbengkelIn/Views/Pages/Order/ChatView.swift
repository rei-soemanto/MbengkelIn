//
//  ChatView.swift
//  MbengkelIn
//
//  Created by Bryan Fernando Dinata on 28/05/26.
//

import SwiftUI

struct ChatView: View {
    let bengkel: Bengkel?

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "bubble.left.and.bubble.right.fill")
                .font(.system(size: 56))
                .foregroundColor(.primary)
            Text("Chat dengan \(bengkel?.name ?? "Bengkel")")
                .font(.title3.bold())
                .multilineTextAlignment(.center)
            Text("Fitur chat akan segera hadir.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Chat")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        ChatView(bengkel: nil)
    }
}
