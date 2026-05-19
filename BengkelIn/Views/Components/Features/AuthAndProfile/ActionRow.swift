//
//  ActionRow.swift
//  BengkelIn
//
//  Created by Rei Soemanto on 23/04/26.
//

import SwiftUI

struct ActionRow: View {
    var icon: String
    var title: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .frame(width: 30)
                .foregroundColor(Color.primary)
            Text(title)
                .foregroundColor(Color.primary)
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundColor(.gray)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}
