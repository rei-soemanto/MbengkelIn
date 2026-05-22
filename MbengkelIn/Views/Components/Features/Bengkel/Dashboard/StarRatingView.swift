//
//  StarRatingView.swift
//  MbengkelIn
//
//  Created by Rei Soemanto on 25/04/26.
//

import SwiftUI

struct StarRatingView: View {
    var rating: Double
    var maxRating: Int = 5
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<maxRating, id: \.self) { index in
                Image(systemName: "star.fill")
                    .foregroundColor(Color.gray.opacity(0.3))
                    .overlay(
                        GeometryReader { geometry in
                            let fillAmount = max(0, min(1, rating - Double(index)))
                            
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                                .frame(width: geometry.size.width * CGFloat(fillAmount), alignment: .leading)
                                .clipped()
                        }
                    )
            }
        }
    }
}
