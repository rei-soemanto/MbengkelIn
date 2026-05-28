import SwiftUI

struct PlaceBidSheet: View {
    let minPrice: Int
    let onSubmit: (Int, String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var priceText: String = ""
    @State private var notes: String = ""

    init(minPrice: Int = 0, onSubmit: @escaping (Int, String) -> Void) {
        self.minPrice = minPrice
        self.onSubmit = onSubmit
        _priceText = State(initialValue: minPrice > 0 ? String(minPrice) : "")
    }

    private var price: Int {
        Int(priceText) ?? 0
    }

    private var isValid: Bool {
        price >= minPrice && price > 0
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Harga Tawaran")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    TextField("Rp", text: $priceText)
                        .keyboardType(.numberPad)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    if minPrice > 0 {
                        Text("Minimal Rp\(minPrice) (harga pelanggan)")
                            .font(.caption)
                            .foregroundColor(price < minPrice && !priceText.isEmpty ? .red : .secondary)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Catatan")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    TextField("Opsional", text: $notes)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                }

                PrimaryButton(title: "Kirim Tawaran", iconName: "paperplane.fill") {
                    guard isValid else { return }
                    onSubmit(price, notes)
                    dismiss()
                }
                .disabled(!isValid)
                .opacity(isValid ? 1 : 0.5)

                Spacer()
            }
            .padding()
            .navigationTitle("Beri Tawaran")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Batal") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    PlaceBidSheet(minPrice: 50000, onSubmit: { _, _ in })
}
