//
//  ProfileView.swift
//  BengkelIn
//
//  Created by Rei Soemanto on 23/04/26.
//

import SwiftUI
import PhotosUI

struct ProfileView: View {
    @ObservedObject var authViewModel: AuthViewModel
    
    @StateObject private var profileViewModel = ProfileViewModel()
    @StateObject private var vehicleViewModel = VehicleViewModel()
    
    @State private var showDeleteAlert = false
    @State private var passwordForDeletion = ""
    @State private var showResetPasswordAlert = false
    
    @State private var selectedPhotoItem: PhotosPickerItem?
    
    var body: some View {
        NavigationStack {
            ZStack {
                ScrollView {
                    VStack(spacing: 24) {
                        
                        VStack(spacing: 12) {
                            ZStack(alignment: .bottomTrailing) {
                                if let imageUrlString = authViewModel.currentUser?.profileImageUrl,
                                   let url = URL(string: imageUrlString) {
                                    AsyncImage(url: url) { phase in
                                        switch phase {
                                        case .empty:
                                            ProgressView()
                                                .frame(width: 100, height: 100)
                                        case .success(let image):
                                            image
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: 100, height: 100)
                                                .clipShape(Circle())
                                        case .failure:
                                            Image(systemName: "person.circle.fill")
                                                .resizable()
                                                .scaledToFit()
                                                .frame(width: 100, height: 100)
                                                .foregroundColor(Color(.systemGray3))
                                        @unknown default:
                                            EmptyView()
                                        }
                                    }
                                } else {
                                    Image(systemName: "person.circle.fill")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 100, height: 100)
                                        .foregroundColor(Color(.systemGray3))
                                        .clipShape(Circle())
                                }
                                
                                PhotosPicker(selection: $selectedPhotoItem, matching: .images, photoLibrary: .shared()) {
                                    Image(systemName: "pencil.circle.fill")
                                        .resizable()
                                        .frame(width: 30, height: 30)
                                        .foregroundColor(.primary.opacity(0.8))
                                        .background(Circle().fill(Color(.systemBackground)))
                                }
                                .onChange(of: selectedPhotoItem) { oldValue, newValue in
                                    Task {
                                        if let data = try? await newValue?.loadTransferable(type: Data.self) {
                                            let success = await profileViewModel.uploadProfileImage(data)
                                            if success {
                                                await authViewModel.fetchUser()
                                            }
                                        }
                                    }
                                }
                            }
                            
                            VStack(spacing: 4) {
                                Text(authViewModel.currentUser?.name ?? "User Name")
                                    .font(.title)
                                    .fontWeight(.bold)
                                Text(authViewModel.currentUser?.email ?? "email@example.com")
                                    .font(.default)
                                    .foregroundColor(.gray)
                                Text(authViewModel.currentUser?.phoneNumber ?? "+62 812 3456 7890")
                                    .font(.default)
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding(.top, 20)
                        
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text("My Vehicles").font(.headline)
                                Spacer()
                                NavigationLink(destination: VehicleFormView(vehicleViewModel: vehicleViewModel)) {
                                    Image(systemName: "plus.circle.fill").font(.title2).foregroundColor(Color.primary.opacity(0.9))
                                }
                            }
                            
                            if vehicleViewModel.userVehicles.isEmpty {
                                Text("No vehicles added yet.")
                                    .foregroundColor(.gray)
                                    .font(.subheadline)
                                    .padding(.vertical, 10)
                            } else {
                                ForEach(vehicleViewModel.userVehicles) { vehicle in
                                    VehicleCardRow(vehicleViewModel: vehicleViewModel, vehicle: vehicle)
                                }
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(16)
                        
                        VStack(spacing: 16) {
                            NavigationLink(destination: UpdateProfileView(authViewModel: authViewModel, profileViewModel: profileViewModel)) {
                                ActionRow(icon: "person.text.rectangle", title: "Profile Settings")
                            }
                            
                            NavigationLink(destination: RegisterBengkelPlaceholder()) {
                                ActionRow(icon: "wrench.and.screwdriver", title: "Register as Bengkel")
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Danger Zone")
                                .font(.headline)
                                .foregroundColor(.red)
                            
                            VStack(spacing: 0) {
                                Button(action: {
                                    Task { await authViewModel.sendPasswordResetEmail() }
                                    showResetPasswordAlert = true
                                }) {
                                    DangerRow(icon: "lock.rotation", title: "Change Password")
                                }
                                Divider()
                                
                                Button(action: {
                                    authViewModel.signOut()
                                }) {
                                    DangerRow(icon: "rectangle.portrait.and.arrow.right", title: "Log Out")
                                }
                                Divider()
                                
                                Button(action: {
                                    showDeleteAlert = true
                                }) {
                                    DangerRow(icon: "trash", title: "Delete Account", isDestructive: true)
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
                    .padding(.horizontal)
                    .padding(.bottom, 40)
                }
                
                if profileViewModel.isLoading {
                    Color.black.opacity(0.3).ignoresSafeArea()
                    ProgressView()
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(10)
                        .shadow(radius: 10)
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            
            .task {
                await vehicleViewModel.fetchVehicles()
            }
            
            .alert("Password Reset Sent", isPresented: $showResetPasswordAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(authViewModel.successMessage ?? "Check your email for the reset link.")
            }
            
            .alert("Delete Account", isPresented: $showDeleteAlert) {
                SecureField("Enter your password", text: $passwordForDeletion)
                Button("Cancel", role: .cancel) { passwordForDeletion = "" }
                Button("Delete", role: .destructive) {
                    Task {
                        await authViewModel.deleteAccount(password: passwordForDeletion)
                        passwordForDeletion = ""
                    }
                }
            } message: {
                Text("This action cannot be undone. Please enter your password to confirm.")
            }
        }
    }
}

#Preview("Light Theme") {
    ProfileView(
        authViewModel: AuthViewModel()
    )
    .preferredColorScheme(.light)
}

#Preview("Dark Theme") {
    ProfileView(
        authViewModel: AuthViewModel()
    )
    .preferredColorScheme(.dark)
}
