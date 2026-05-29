import SwiftUI

// Small tappable thumbnail of the damage photo; opens a full-screen viewer.
struct OrderPhotoThumbnail: View {
    let photoUrl: String
    @State private var showPhoto = false

    var body: some View {
        if let url = URL(string: photoUrl) {
            Button { showPhoto = true } label: {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .failure:
                        Image(systemName: "photo").foregroundColor(.secondary)
                    default:
                        ProgressView()
                    }
                }
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color(.systemGray4), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .fullScreenCover(isPresented: $showPhoto) {
                OrderPhotoViewer(photoUrl: photoUrl) { showPhoto = false }
            }
        }
    }
}

struct OrderPhotoViewer: View {
    let photoUrl: String
    let onClose: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()
            if let url = URL(string: photoUrl) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFit()
                    case .failure:
                        Image(systemName: "photo")
                            .font(.largeTitle).foregroundColor(.white)
                    default:
                        ProgressView().tint(.white)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title)
                    .foregroundStyle(.white, .black.opacity(0.4))
                    .padding()
            }
        }
    }
}
