//
//  ProfileView.swift
//  BengkelIn
//
//  Created by Rei Soemanto on 23/04/26.
//

import SwiftUI

struct ProfileView: View {
    @ObservedObject var viewModel: AuthViewModel
    
    @State private var vehicles: [Vehicle] = [
        Vehicle(customerId: "1", make: "Toyota", model: "Avanza", year: 2018, licensePlate: "L 1234 AB", color: "Silver"),
        Vehicle(customerId: "1", make: "Honda", model: "Beat", year: 2021, licensePlate: "W 5678 CD", color: "Black")
    ]
    
    @State private var showDeleteAlert = false
    @State private var passwordForDeletion = ""
    @State private var showResetPasswordAlert = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    
                    VStack(spacing: 12) {
                        ZStack(alignment: .bottomTrailing) {
                            
                            Image(systemName: "person.circle.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 100, height: 100)
                                .foregroundColor(Color(.systemGray3))
                                .clipShape(Circle())
                            
                            Button(action: {
                                print("Edit picture tapped")
                            }) {
                                Image(systemName: "pencil.circle.fill")
                                    .resizable()
                                    .frame(width: 30, height: 30)
                                    .foregroundColor(.primary.opacity(0.8))
                                    .background(Circle().fill(Color(.systemBackground)))
                            }
                        }
                        
                        VStack(spacing: 4) {
                            Text(viewModel.currentUser?.name ?? "User Name")
                                .font(.title2)
                                .fontWeight(.bold)
                            Text(viewModel.currentUser?.email ?? "email@example.com")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                            Text(viewModel.currentUser?.phoneNumber ?? "+62 812 3456 7890")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(.top, 20)
                    
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("My Vehicles")
                                .font(.headline)
                            Spacer()
                            NavigationLink(destination: AddVehiclePlaceholder()) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(.blue)
                            }
                        }
                        
                        if vehicles.isEmpty {
                            Text("No vehicles added yet.")
                                .foregroundColor(.gray)
                                .font(.subheadline)
                                .padding(.vertical, 10)
                        } else {
                            ForEach(vehicles) { vehicle in
                                VehicleCardRow(vehicle: vehicle)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(16)
                    
                    VStack(spacing: 16) {
                        NavigationLink(destination: UpdateProfilePlaceholder()) {
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
                                Task { await viewModel.sendPasswordResetEmail() }
                                showResetPasswordAlert = true
                            }) {
                                DangerRow(icon: "lock.rotation", title: "Change Password")
                            }
                            Divider()
                            
                            Button(action: {
                                viewModel.signOut()
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
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            
            .alert("Password Reset Sent", isPresented: $showResetPasswordAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(viewModel.successMessage ?? "Check your email for the reset link.")
            }
            
            .alert("Delete Account", isPresented: $showDeleteAlert) {
                SecureField("Enter your password", text: $passwordForDeletion)
                Button("Cancel", role: .cancel) { passwordForDeletion = "" }
                Button("Delete", role: .destructive) {
                    Task {
                        await viewModel.deleteAccount(password: passwordForDeletion)
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
        viewModel: AuthViewModel()
    )
    .preferredColorScheme(.light)
}

#Preview("Dark Theme") {
    ProfileView(
        viewModel: AuthViewModel()
    )
    .preferredColorScheme(.dark)
}
