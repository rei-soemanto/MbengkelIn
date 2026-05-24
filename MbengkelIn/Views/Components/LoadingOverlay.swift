import SwiftUI

enum LoadingPhase: Equatable {
    case idle
    case loading(message: String)
    case failed(title: String, message: String)
}

struct LoadingOverlay: View {
    let phase: LoadingPhase
    var onRetry: (() -> Void)?
    var onStop: (() -> Void)?

    var body: some View {
        switch phase {
        case .idle:
            EmptyView()
        case .loading(let message):
            container {
                VStack(spacing: 20) {
                    ProgressView()
                        .scaleEffect(1.6)
                        .tint(.primary)
                    Text(message)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(32)
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 8)
            }
        case .failed(let title, let message):
            container {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.magnifyingglass")
                        .font(.system(size: 44, weight: .semibold))
                        .foregroundColor(.secondary)
                    Text(title)
                        .font(.title3)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                    Text(message)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    VStack(spacing: 10) {
                        Button(action: { onRetry?() }) {
                            Text("Coba Lagi")
                                .font(.headline)
                                .foregroundColor(Color(.systemBackground))
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.primary.opacity(0.9))
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        Button(action: { onStop?() }) {
                            Text("Berhenti")
                                .font(.headline)
                                .foregroundColor(.primary)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color(.systemGray5))
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                    }
                    .padding(.top, 8)
                }
                .padding(28)
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 8)
                .padding(.horizontal, 40)
            }
        }
    }

    @ViewBuilder
    private func container<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
            content()
        }
        .transition(.opacity)
    }
}

extension View {
    func loadingOverlay(
        phase: LoadingPhase,
        onRetry: (() -> Void)? = nil,
        onStop: (() -> Void)? = nil
    ) -> some View {
        overlay {
            LoadingOverlay(phase: phase, onRetry: onRetry, onStop: onStop)
                .animation(.easeInOut(duration: 0.25), value: phase)
        }
    }
}
