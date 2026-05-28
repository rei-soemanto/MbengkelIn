//
//  BengkelProfileView.swift
//  MbengkelIn
//
//  Created by Rei Soemanto on 26/04/26.
//

import SwiftUI

struct BengkelProfileView: View {
    @ObservedObject var authViewModel: AuthViewModel
    
    @StateObject private var bengkelViewModel = BengkelViewModel()
    
    @State private var showDeleteBengkelAlert = false
    @State private var passwordForDeletion = ""
    
    var previewBengkel: Bengkel? = nil
    
    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()
            
            if bengkelViewModel.isLoading && bengkelViewModel.myBengkel == nil {
                ProgressView("Loading Bengkel data...")
            } else if let bengkel = bengkelViewModel.myBengkel {
                ScrollView {
                    VStack(spacing: 24) {
                        if let errorMessage = bengkelViewModel.errorMessage {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                Text(errorMessage)
                                    .font(.subheadline)
                                Spacer()
                            }
                            .padding()
                            .background(Color.red.opacity(0.1))
                            .foregroundColor(.red)
                            .cornerRadius(10)
                            .padding(.top, 10)
                        } else if let successMessage = bengkelViewModel.successMessage {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                Text(successMessage)
                                    .font(.subheadline)
                                Spacer()
                            }
                            .padding()
                            .background(Color.green.opacity(0.1))
                            .foregroundColor(.green)
                            .cornerRadius(10)
                            .padding(.top, 10)
                        }
                        
                        VStack(spacing: 12) {
                            Image(systemName: "wrench.and.screwdriver.fill")
                                .resizable()
                                .frame(width: 100, height: 100)
                                .foregroundColor(Color.primary.opacity(0.8))
                            
                            Text(bengkel.name)
                                .font(.title)
                                .fontWeight(.bold)
                            
                            Text(bengkel.status.uppercased())
                                .font(.caption)
                                .fontWeight(.bold)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(bengkel.status == "Verified" ? Color.green.opacity(0.2) : Color.orange.opacity(0.2))
                                .foregroundColor(bengkel.status == "Verified" ? .green : .orange)
                                .cornerRadius(8)
                        }
                        .padding(.top, 20)
                        
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Detail Bengkel")
                                .font(.headline)
                            
                            Divider()
                            
                            HStack(alignment: .top) {
                                Image(systemName: "mappin.and.ellipse")
                                    .foregroundColor(.gray)
                                    .frame(width: 24)
                                Text(bengkel.address)
                                    .font(.subheadline)
                            }
                            
                            HStack {
                                Image(systemName: "star.fill")
                                    .foregroundColor(.yellow)
                                    .frame(width: 24)
                                Text("\(bengkel.averageRating, specifier: "%.1f") (\(bengkel.totalReviews) Ulasan)")
                                    .font(.subheadline)
                            }
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text("Layanan yang Ditawarkan")
                                    .font(.headline)
                                Spacer()
                                
                                NavigationLink(destination: BengkelServiceFormView(bengkelViewModel: bengkelViewModel)) {
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundColor(.primary)
                                        .font(.title2)
                                }
                            }
                            
                            if bengkel.offeredServices.isEmpty {
                                Text("Anda belum menambahkan layanan apa pun.")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                    .padding(.vertical, 8)
                            } else {
                                ForEach(bengkel.offeredServices) { service in
                                    HStack(alignment: .top) {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(service.serviceType.rawValue)
                                                .font(.body)
                                                .fontWeight(service.isActive ? .semibold : .regular)
                                                .foregroundColor(service.isActive ? .primary : .gray)
                                            
                                            if !service.isActive {
                                                Text("Tidak Aktif")
                                                    .font(.caption2)
                                                    .fontWeight(.bold)
                                                    .foregroundColor(.red)
                                                    .padding(.horizontal, 8)
                                                    .padding(.vertical, 4)
                                                    .background(Color.red.opacity(0.1))
                                                    .cornerRadius(6)
                                            }
                                        }
                                        Spacer()
                                        
                                        NavigationLink(destination: BengkelServiceFormView(bengkelViewModel: bengkelViewModel, serviceToEdit: service)) {
                                            Image(systemName: "pencil")
                                                .font(.subheadline)
                                                .foregroundColor(.blue)
                                                .padding(8)
                                                .background(Color.blue.opacity(0.1))
                                                .clipShape(Circle())
                                        }
                                        
                                        Button(action: {
                                            Task {
                                                guard let bengkelId = bengkelViewModel.myBengkel?.id else { return }
                                                await bengkelViewModel.deleteService(bengkelId: bengkelId, serviceId: service.id)
                                            }
                                        }) {
                                            Image(systemName: "xmark")
                                                .font(.subheadline)
                                                .foregroundColor(.red)
                                                .padding(8)
                                                .background(Color.red.opacity(0.1))
                                                .clipShape(Circle())
                                        }
                                    }
                                    .padding(.vertical, 6)
                                    Divider()
                                }
                            }
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        
                        VStack(spacing: 16) {
                            NavigationLink(destination: UpdateBengkelView(bengkelViewModel: bengkelViewModel, authViewModel: authViewModel, bengkel: bengkel)) {
                                ActionRow(icon: "pencil.circle", title: "Edit Bengkel Settings")
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Zona Berbahaya")
                                .font(.headline)
                                .foregroundColor(.red)
                            
                            VStack(spacing: 0) {
                                Button(action: {
                                    showDeleteBengkelAlert = true
                                }) {
                                    DangerRow(icon: "trash", title: "Delete Bengkel", isDestructive: true)
                                }
                            }
                            .background(Color(.systemBackground))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.red.opacity(0.3), lineWidth: 1)
                            )
                        }
                        .padding(.top, 10)
                        
                    }
                    .padding()
                }
            } else if let error = bengkelViewModel.errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding()
            }
        }
        .navigationTitle("Profil Bengkel")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if let mock = previewBengkel {
                bengkelViewModel.myBengkel = mock
            } else if let uid = authViewModel.currentUser?.id {
                await bengkelViewModel.startWatching(uid: uid)
            }
        }
        .onDisappear {
            bengkelViewModel.stopWatching()
        }
        .alert("Delete Bengkel", isPresented: $showDeleteBengkelAlert) {
            SecureField("Masukkan kata sandi Anda", text: $passwordForDeletion)
            Button("Batal", role: .cancel) { passwordForDeletion = "" }
            Button("Hapus", role: .destructive) {
                Task {
                    guard let email = authViewModel.currentUser?.email,
                          let bengkelId = bengkelViewModel.myBengkel?.id else { return }
                    
                    let success = await bengkelViewModel.deleteBengkel(bengkelId: bengkelId, password: passwordForDeletion, email: email)
                    
                    if success {
                        await authViewModel.fetchUser()
                        authViewModel.appMode = .customer
                    }
                    passwordForDeletion = ""
                }
            }
        } message: {
            Text("Tindakan ini tidak dapat dibatalkan. Akun Anda akan diturunkan menjadi pengguna biasa.")
        }
    }
}

#Preview("Light Theme") {
    NavigationStack {
        BengkelProfileView(authViewModel: AuthViewModel())
    }
    .preferredColorScheme(.light)
}

#Preview("Dark Theme") {
    NavigationStack {
        BengkelProfileView(authViewModel: AuthViewModel())
    }
    .preferredColorScheme(.dark)
}
