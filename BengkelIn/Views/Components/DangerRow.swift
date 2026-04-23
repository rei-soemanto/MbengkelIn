//
//  DangerRow.swift
//  BengkelIn
//
//  Created by Rei Soemanto on 23/04/26.
//

import SwiftUI

struct DangerRow: View {
    var icon: String
    var title: String
    var isDestructive: Bool = false
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .frame(width: 30)
                .foregroundColor(isDestructive ? .red : Color.primary)
            Text(title)
                .foregroundColor(isDestructive ? .red : Color.primary)
                .fontWeight(isDestructive ? .bold : .regular)
            Spacer()
        }
        .padding()
    }
}
