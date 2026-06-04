import SwiftUI
import PhotosUI

struct CompleteOrderButton: View {
    @StateObject private var viewModel: OrderCompletionViewModel
    @Environment(\.scenePhase) private var scenePhase
    @State private var photoItem: PhotosPickerItem?

    private let isCustomer: Bool
    private let canComplete: Bool

    init(requestId: String, isCustomer: Bool, canComplete: Bool = true) {
        self.isCustomer = isCustomer
        self.canComplete = canComplete
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
        .onChange(of: scenePhase) { _, phase in
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
            VStack(spacing: 6) {
                statusLabel(text: "Menunggu konfirmasi pihak lain", icon: "clock.fill", color: .orange)
                Text("Dana ditahan sampai kedua pihak menyelesaikan pesanan.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        } else if !canComplete {
            statusLabel(text: "Menunggu bengkel tiba di lokasi", icon: "location.circle", color: .secondary)
        } else if isCustomer {
            Button {
                Task { await viewModel.markCompleted() }
            } label: {
                buttonLabel
            }
            .disabled(viewModel.isLoading)
        } else {
            PhotosPicker(selection: $photoItem, matching: .images) {
                buttonLabel
            }
            .disabled(viewModel.isLoading)
            .onChange(of: photoItem) { _, item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self) {
                        await viewModel.markCompleted(photoData: data)
                    } else {
                        viewModel.errorMessage = "Gagal memuat foto. Coba pilih ulang."
                    }
                    photoItem = nil
                }
            }
        }
    }

    private var buttonLabel: some View {
        HStack {
            if viewModel.isLoading {
                ProgressView().tint(Color(.systemBackground))
            } else {
                Image(systemName: isCustomer ? "checkmark.circle.fill" : "camera.fill")
                Text(isCustomer ? "Selesaikan Pesanan" : "Selesaikan + Foto").fontWeight(.bold)
            }
        }
        .foregroundColor(Color(.systemBackground))
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color.primary.opacity(0.9))
        .cornerRadius(16)
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
