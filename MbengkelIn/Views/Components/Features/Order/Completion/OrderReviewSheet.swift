//
//  OrderReviewSheet.swift
//  MbengkelIn
//
//  Created by Amadeus Eugine Dirgantara on 29/05/26.
//

import SwiftUI

// A self-contained rating + review sheet. Used for the automatic prompt shown
// when an order completes, and reusable anywhere a review is collected.
struct OrderReviewSheet: View {
    let requestId: String
    var existingRating: Int? = nil
    var onSubmitted: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = OrderRatingViewModel()
    @State private var rating: Int = 0
    @State private var reviewText: String = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                if let existingRating {
                    alreadyRatedContent(existingRating)
                } else {
                    editableForm
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(existingRating == nil ? "Beri Penilaian" : "Penilaian Anda")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Let the customer skip and review later from history (editable only).
                if existingRating == nil {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Nanti") { dismiss() }
                    }
                }
            }
            .alert("Terjadi Kesalahan", isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { viewModel.errorMessage = nil }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
        .interactiveDismissDisabled(viewModel.isSubmitting)
    }

    // Read-only state shown when the order has already been rated. The DB's
    // rate_order RPC also rejects a second rating, so this is purely UX.
    private func alreadyRatedContent(_ existingRating: Int) -> some View {
        VStack(spacing: 24) {
            VStack(spacing: 10) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 52))
                    .foregroundColor(.green)
                Text("Terima Kasih")
                    .font(.title2.bold())
                Text("Anda sudah memberi penilaian untuk pesanan ini.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 24)

            StarRatingView(rating: Double(existingRating))
                .font(.title)

            Button {
                dismiss()
            } label: {
                Text("Tutup")
                    .font(.headline)
                    .foregroundColor(Color(.systemBackground))
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.primary.opacity(0.9))
                    .cornerRadius(16)
            }
        }
        .padding()
    }

    private var editableForm: some View {
        VStack(spacing: 24) {
            VStack(spacing: 10) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 52))
                    .foregroundColor(.green)
                Text("Pesanan Selesai")
                    .font(.title2.bold())
                Text("Bagaimana pengalaman servis Anda?")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 24)

            InteractiveStarRating(rating: $rating)

            TextField("Tulis ulasan (opsional)", text: $reviewText, axis: .vertical)
                .lineLimit(3...6)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)

            Button {
                Task {
                    let ok = await viewModel.submit(
                        requestId: requestId,
                        rating: rating,
                        review: reviewText
                    )
                    if ok {
                        onSubmitted()
                        dismiss()
                    }
                }
            } label: {
                Text(viewModel.isSubmitting ? "Mengirim..." : "Kirim Penilaian")
                    .font(.headline)
                    .foregroundColor(Color(.systemBackground))
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.primary.opacity(rating > 0 ? 0.9 : 0.3))
                    .cornerRadius(16)
            }
            .disabled(rating == 0 || viewModel.isSubmitting)
        }
        .padding()
    }
}
