//
//  OrderStatusBadge.swift
//  MbengkelIn
//
//  Created by Bryan Fernando Dinata on 28/05/26.
//

import SwiftUI

struct OrderStatusBadge: View {
    let status: String

    var body: some View {
        Text(label)
            .font(.caption2.bold())
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(color.opacity(0.15))
            .foregroundColor(color)
            .clipShape(Capsule())
    }

    private var label: String {
        switch status {
        case "To Do": return "Mencari Mekanik"
        case "On Progress": return "Berlangsung"
        case "Done": return "Selesai"
        case "Cancelled": return "Dibatalkan"
        default: return status
        }
    }

    private var color: Color {
        switch status {
        case "To Do": return .orange
        case "On Progress": return .green
        case "Done": return .blue
        case "Cancelled": return .red
        default: return .gray
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        OrderStatusBadge(status: "To Do")
        OrderStatusBadge(status: "On Progress")
        OrderStatusBadge(status: "Done")
        OrderStatusBadge(status: "Cancelled")
    }
}
