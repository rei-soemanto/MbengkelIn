//
//  UnreadBadge.swift
//  MbengkelIn
//
//  Created by Bryan Fernando Dinata on 29/05/26.
//

import SwiftUI

struct UnreadBadge: View {
    let count: Int

    var body: some View {
        if count > 0 {
            Text(count > 99 ? "99+" : "\(count)")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .frame(minWidth: 18)
                .background(Color.red)
                .clipShape(Capsule())
                .offset(x: 6, y: -6)
        }
    }
}

#Preview {
    HStack(spacing: 24) {
        Image(systemName: "message.fill")
            .font(.title3)
            .padding(12)
            .background(Color(.systemGray6))
            .clipShape(Circle())
            .overlay(alignment: .topTrailing) { UnreadBadge(count: 3) }

        Image(systemName: "message.fill")
            .font(.title3)
            .padding(12)
            .background(Color(.systemGray6))
            .clipShape(Circle())
            .overlay(alignment: .topTrailing) { UnreadBadge(count: 120) }
    }
    .padding()
}
