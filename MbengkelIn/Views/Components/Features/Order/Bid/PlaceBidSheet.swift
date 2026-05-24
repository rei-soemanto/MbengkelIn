import SwiftUI

struct PlaceBidSheet: View {
    let onSubmit: (Int, String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var priceText: String = ""
    @State private var notes: String = ""

    private var price: Int {
        Int(priceText) ?? 0
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
                    guard price > 0 else { return }
                    onSubmit(price, notes)
                    dismiss()
                }
                .disabled(price <= 0)
                .opacity(price <= 0 ? 0.5 : 1)

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
    PlaceBidSheet(onSubmit: { _, _ in })
}
