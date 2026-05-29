import SwiftUI
import PhotosUI

// One photo slot per problematic tire; the customer must fill every slot.
struct TirePhotoGrid: View {
    let count: Int
    @Binding var photos: [Data?]

    private let columns = [GridItem(.adaptive(minimum: 100), spacing: 12)]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Foto kondisi ban (satu per ban)")
                .font(.subheadline)
                .foregroundColor(.secondary)
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(0..<count, id: \.self) { index in
                    TirePhotoSlot(index: index, data: binding(for: index))
                }
            }
        }
        .padding(.horizontal)
    }

    private func binding(for index: Int) -> Binding<Data?> {
        Binding(
            get: { index < photos.count ? photos[index] : nil },
            set: { if index < photos.count { photos[index] = $0 } }
        )
    }
}

struct TirePhotoSlot: View {
    let index: Int
    @Binding var data: Data?
    @State private var item: PhotosPickerItem?

    var body: some View {
        PhotosPicker(selection: $item, matching: .images) {
            ZStack {
                if let data, let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage).resizable().scaledToFill()
                } else {
                    VStack(spacing: 4) {
                        Image(systemName: "camera.fill")
                        Text("Ban \(index + 1)").font(.caption)
                    }
                    .foregroundColor(.secondary)
                }
            }
            .frame(height: 100)
            .frame(maxWidth: .infinity)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .onChange(of: item) { newItem in
            Task {
                if let loaded = try? await newItem?.loadTransferable(type: Data.self) {
                    data = loaded
                }
            }
        }
    }
}
