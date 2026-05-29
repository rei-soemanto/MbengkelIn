//
//  ChatView.swift
//  MbengkelIn
//
//  Created by Bryan Fernando Dinata on 28/05/26.
//

import SwiftUI
import PhotosUI

private struct ZoomableImageURL: Identifiable {
    let id = UUID()
    let url: String
}

struct ChatView: View {
    let title: String

    @StateObject private var viewModel: ChatViewModel
    @State private var photoItem: PhotosPickerItem?
    @State private var fullScreenImage: ZoomableImageURL?

    init(serviceRequestId: String, title: String = "Chat") {
        self.title = title
        _viewModel = StateObject(wrappedValue: ChatViewModel(serviceRequestId: serviceRequestId))
    }

    var body: some View {
        VStack(spacing: 0) {
            messagesList
            if viewModel.isLocked {
                lockedBanner
            } else {
                inputBar
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.start() }
        .onAppear { ChatPresence.shared.activeServiceRequestId = viewModel.serviceRequestId }
        .onDisappear {
            if ChatPresence.shared.activeServiceRequestId == viewModel.serviceRequestId {
                ChatPresence.shared.activeServiceRequestId = nil
            }
        }
        .onChange(of: photoItem) { _, newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self) {
                    let jpeg = UIImage(data: data)?.jpegData(compressionQuality: 0.7) ?? data
                    await viewModel.sendImage(data: jpeg)
                }
                photoItem = nil
            }
        }
        .fullScreenCover(item: $fullScreenImage) { item in
            FullScreenImageView(urlString: item.url)
        }
    }

    private var messagesList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 10) {
                    if viewModel.messages.isEmpty {
                        Text("Belum ada pesan. Mulai percakapan.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.top, 40)
                    }
                    ForEach(viewModel.messages) { message in
                        bubble(message).id(message.id)
                    }
                }
                .padding()
            }
            .onChange(of: viewModel.messages.count) { _, _ in
                if let last = viewModel.messages.last {
                    withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
        }
    }

    private func bubble(_ message: ChatMessage) -> some View {
        let mine = message.senderId == viewModel.currentUserId
        return HStack {
            if mine { Spacer(minLength: 48) }
            VStack(alignment: mine ? .trailing : .leading, spacing: 6) {
                if let urlString = message.imageUrl, let url = URL(string: urlString) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFill()
                        case .failure:
                            Image(systemName: "photo")
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .foregroundColor(.secondary)
                        default:
                            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                    .frame(width: 200, height: 200)
                    .clipped()
                    .cornerRadius(12)
                    .onTapGesture { fullScreenImage = ZoomableImageURL(url: urlString) }
                }
                if let content = message.content, !content.isEmpty {
                    Text(content)
                        .font(.subheadline)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(mine ? Color.primary.opacity(0.9) : Color(.systemGray5))
                        .foregroundColor(mine ? Color(.systemBackground) : .primary)
                        .cornerRadius(16)
                }
            }
            if !mine { Spacer(minLength: 48) }
        }
        .frame(maxWidth: .infinity, alignment: mine ? .trailing : .leading)
    }

    private var inputBar: some View {
        HStack(spacing: 12) {
            PhotosPicker(selection: $photoItem, matching: .images) {
                Image(systemName: "photo")
                    .font(.title3)
                    .foregroundColor(.primary)
            }

            TextField("Tulis pesan...", text: $viewModel.draft, axis: .vertical)
                .lineLimit(1...4)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.systemGray6))
                .cornerRadius(20)

            Button {
                Task { await viewModel.sendText() }
            } label: {
                Image(systemName: "paperplane.fill")
                    .font(.title3)
                    .foregroundColor(Color(.systemBackground))
                    .padding(10)
                    .background(Color.primary.opacity(0.9))
                    .clipShape(Circle())
            }
            .disabled(viewModel.isSending || viewModel.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding()
        .background(Color(.systemBackground))
    }

    private var lockedBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "lock.fill")
            Text("Pesanan telah selesai. Chat ditutup.")
        }
        .font(.subheadline)
        .foregroundColor(.secondary)
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemBackground))
    }
}

private struct FullScreenImageView: View {
    let urlString: String
    @Environment(\.dismiss) private var dismiss
    @State private var scale: CGFloat = 1

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()
            AsyncImage(url: URL(string: urlString)) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFit()
                        .scaleEffect(scale)
                        .gesture(
                            MagnificationGesture()
                                .onChanged { scale = max(1, $0) }
                                .onEnded { _ in withAnimation { scale = max(1, scale) } }
                        )
                case .failure:
                    Image(systemName: "photo").foregroundColor(.white)
                default:
                    ProgressView().tint(.white)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title)
                    .foregroundColor(.white)
                    .padding()
            }
        }
    }
}

#Preview {
    NavigationStack {
        ChatView(serviceRequestId: "preview", title: "Bengkel Jaya")
    }
}
