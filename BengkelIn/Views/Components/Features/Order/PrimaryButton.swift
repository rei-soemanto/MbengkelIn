//
//  PrimaryButton.swift
//  BengkelIn
//
//  Created by Bryan Fernando Dinata on 19/05/26.
//


import SwiftUI

struct PrimaryButton: View {
    let title: String
    let iconName: String?
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                if let iconName = iconName {
                    Image(systemName: iconName)
                        .font(.system(size: 20, weight: .bold))
                }
                Text(title)
                    .font(.headline)
                    .fontWeight(.bold)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.black)
            .cornerRadius(16)
        }
    }
}
