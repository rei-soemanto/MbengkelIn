//
//  UpdateBengkelView.swift
//  BengkelIn
//
//  Created by Rei Soemanto on 25/04/26.
//

import SwiftUI

struct UpdateBengkelView: View {
    @ObservedObject var bengkelViewModel: BengkelViewModel
    @ObservedObject var authViewModel: AuthViewModel
    var bengkel: Bengkel
    
    @Environment(\.dismiss) var dismiss
    
    @State private var name: String = ""
    @State private var address: String = ""
    
    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 16) {
                    
                    Image(systemName: "building.2.crop.circle.fill")
                        .resizable()
                        .frame(width: 100, height: 100)
                        .foregroundColor(Color.primary.opacity(0.8))
                        .padding(.vertical)
                    
                    CustomInputField(iconName: "building.2", placeholder: "Bengkel Name", text: $name)
                    
                    CustomInputField(iconName: "map", placeholder: "Full Address", text: $address)
                    
                    if let errorMessage = bengkelViewModel.errorMessage {
                        Text(errorMessage).foregroundColor(.red).font(.footnote)
                    }
                    
                    Button {
                        Task {
                            guard let id = bengkel.id else { return }
                            let success = await bengkelViewModel.updateBengkel(bengkelId: id, name: name, address: address)
                            
                            if success {
                                if let uid = authViewModel.currentUser?.id {
                                    await bengkelViewModel.fetchMyBengkel(uid: uid)
                                }
                                dismiss()
                            }
                        }
                    } label: {
                        Text("Save Changes")
                            .font(.headline)
                            .foregroundColor(Color(.systemBackground))
                            .frame(maxWidth: .infinity)
                            .frame(height: 55)
                            .background(Color.primary.opacity(0.8))
                            .cornerRadius(12)
                            .shadow(color: Color.primary.opacity(0.15), radius: 10, x: 0, y: 5)
                    }
                    .padding(.top, 10)
                    .disabled(bengkelViewModel.isLoading || name.isEmpty || address.isEmpty)
                }
                .padding()
            }
            
            if bengkelViewModel.isLoading {
                ProgressView("Updating...")
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(10)
                    .shadow(radius: 10)
            }
        }
        .navigationTitle("Edit Bengkel")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            self.name = bengkel.name
            self.address = bengkel.address
        }
    }
}
