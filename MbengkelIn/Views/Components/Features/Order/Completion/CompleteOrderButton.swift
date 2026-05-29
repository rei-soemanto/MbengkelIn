import SwiftUI

struct CompleteOrderButton: View {
    @StateObject private var viewModel: OrderCompletionViewModel
    @Environment(\.scenePhase) private var scenePhase

    init(requestId: String, isCustomer: Bool) {
        _viewModel = StateObject(wrappedValue: OrderCompletionViewModel(requestId: requestId, isCustomer: isCustomer))
    }

    var body: some View {
        VStack(spacing: 8) {
            content
            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            }
        }
        .task { await viewModel.start() }
        .onChange(of: scenePhase) { phase in
            if phase == .active {
                Task { await viewModel.refresh() }
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.status == "Done" {
            statusLabel(text: "Pesanan Selesai", icon: "checkmark.seal.fill", color: .green)
        } else if viewModel.status == "Cancelled" {
            statusLabel(text: "Pesanan Dibatalkan", icon: "xmark.seal.fill", color: .red)
        } else if viewModel.mySideCompleted {
            statusLabel(text: "Menunggu konfirmasi pihak lain", icon: "clock.fill", color: .orange)
        } else {
            Button {
                Task { await viewModel.markCompleted() }
            } label: {
                HStack {
                    if viewModel.isLoading {
                        ProgressView().tint(Color(.systemBackground))
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Selesaikan Pesanan").fontWeight(.bold)
                    }
                }
                .foregroundColor(Color(.systemBackground))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.primary.opacity(0.9))
                .cornerRadius(16)
            }
            .disabled(viewModel.isLoading)
        }
    }

    private func statusLabel(text: String, icon: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
            Text(text).fontWeight(.semibold)
        }
        .font(.subheadline)
        .foregroundColor(color)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(color.opacity(0.12))
        .cornerRadius(16)
    }
}
