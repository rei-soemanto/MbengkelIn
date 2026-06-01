//
//  ReportBehaviorSheet.swift
//  MbengkelIn
//
//  Created by Eugene on 02/06/26.
//

import SwiftUI

struct ReportBehaviorSheet: View {
    let order: NearbyOrder

    @StateObject private var viewModel = BehaviorReportViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var reason = ""

    private var isValid: Bool {
        !reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Laporkan perilaku yang tidak menyenangkan terkait pesanan ini. Laporanmu akan ditinjau oleh admin.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                TextField("Ceritakan apa yang terjadi…", text: $reason, axis: .vertical)
                    .lineLimit(4...8)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                if let error = viewModel.errorMessage {
                    Text(error).font(.caption).foregroundColor(.red)
                }
                Button {
                    Task {
                        if await viewModel.submit(serviceRequestId: order.id, reason: reason) {
                            dismiss()
                        }
                    }
                } label: {
                    Text(viewModel.isSubmitting ? "Mengirim…" : "Kirim Laporan")
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red.opacity(isValid ? 1 : 0.4))
                        .cornerRadius(12)
                }
                .disabled(!isValid || viewModel.isSubmitting)
                Spacer()
            }
            .padding()
            .navigationTitle("Laporkan Perilaku")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Batal") { dismiss() }
                }
            }
        }
        .presentationBackground(.white)
        .presentationDetents([.medium, .large])
    }
}
