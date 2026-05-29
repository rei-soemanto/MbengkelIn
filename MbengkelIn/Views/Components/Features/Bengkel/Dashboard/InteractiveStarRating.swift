//
//  InteractiveStarRating.swift
//  MbengkelIn
//
//  Created by Amadeus Eugine Dirgantara on 29/05/26.
//

import SwiftUI

// Tappable star picker for submitting a rating (1...maxRating).
struct InteractiveStarRating: View {
    @Binding var rating: Int
    var maxRating: Int = 5
    var size: CGFloat = 32

    var body: some View {
        HStack(spacing: 8) {
            ForEach(1...maxRating, id: \.self) { value in
                Image(systemName: value <= rating ? "star.fill" : "star")
                    .font(.system(size: size))
                    .foregroundColor(value <= rating ? .yellow : Color.gray.opacity(0.4))
                    .onTapGesture { rating = value }
                    .accessibilityLabel("\(value) bintang")
            }
        }
    }
}
