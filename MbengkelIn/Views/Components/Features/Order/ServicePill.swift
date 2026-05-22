//
//  ServicePill.swift
//  MbengkelIn
//
//  Created by Bryan Fernando Dinata on 19/05/26.
//


import SwiftUI

struct ServicePill: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .foregroundColor(isSelected ? Color(.systemBackground) : .primary)
                .background(isSelected ? Color.primary.opacity(0.9) : Color(.systemGray5))
                .cornerRadius(20)
        }
    }
}
