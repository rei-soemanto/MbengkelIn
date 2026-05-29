//
//  TireCountSelector.swift
//  MbengkelIn
//
//  Created by Bryan Fernando Dinata on 19/05/26.
//

import SwiftUI

struct TireCountSelector: View {
    let selectedCount: Int
    let onSelect: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Berapa ban yang bermasalah?")
                .font(.subheadline)
                .foregroundColor(.secondary)
            HStack(spacing: 12) {
                ForEach(1...4, id: \.self) { count in
                    Button(action: { onSelect(count) }) {
                        Text("\(count)")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .foregroundColor(selectedCount == count ? Color(.systemBackground) : .primary)
                            .background(selectedCount == count ? Color.primary.opacity(0.9) : Color(.systemGray5))
                            .cornerRadius(12)
                    }
                }
            }
        }
        .padding(.horizontal)
    }
}
