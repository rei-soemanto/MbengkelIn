//
//  UpdateProfileView.swift
//  BengkelIn
//
//  Created by Rei Soemanto on 24/04/26.
//

import SwiftUI

struct UpdateProfileView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @ObservedObject var profileViewModel: ProfileViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var name: String = ""
    @State private var phoneNumber: String = ""
    
    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 16) {
                    
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .frame(width: 100, height: 100)
                        .foregroundColor(Color(.systemGray3))
                        .padding(.vertical)
                    
                    CustomInputField(iconName: "person", placeholder: "Full Name", text: $name)
                    
                    CustomInputField(iconName: "phone", placeholder: "Phone Number", text: $phoneNumber)
                        .keyboardType(.phonePad)
                    
                    HStack {
                        Image(systemName: "envelope").foregroundColor(.gray)
                        Text(authViewModel.currentUser?.email ?? "").foregroundColor(.gray)
                        Spacer()
                    }
                    .padding()
                    .background(Color(.systemGray5))
                    .cornerRadius(12)
                    
                    if let errorMessage = profileViewModel.errorMessage {
                        Text(errorMessage).foregroundColor(.red).font(.footnote)
                    }
                    
                    Button {
                        Task {
                            let success = await profileViewModel.updateProfile(name: name, phoneNumber: phoneNumber)
                            
                            if success {
                                await MainActor.run {
                                    authViewModel.currentUser?.name = name
                                    authViewModel.currentUser?.phoneNumber = phoneNumber
                                    
                                    dismiss()
                                }
                            }
                        }
                    } label: {
                        Text("Update Profile")
                            .font(.headline)
                            .foregroundColor(Color(.systemBackground))
                            .frame(maxWidth: .infinity)
                            .frame(height: 55)
                            .background(Color.primary.opacity(0.8))
                            .cornerRadius(12)
                            .shadow(color: Color.primary.opacity(0.15), radius: 10, x: 0, y: 5)
                    }
                    .padding(.top, 10)
                    .disabled(profileViewModel.isLoading)
                }
                .padding()
            }
            
            if profileViewModel.isLoading {
                ProgressView()
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(10)
                    .shadow(radius: 10)
            }
        }
        .navigationTitle("Edit Profile")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            self.name = authViewModel.currentUser?.name ?? ""
            self.phoneNumber = authViewModel.currentUser?.phoneNumber ?? ""
        }
    }
}

#Preview("Light Theme") {
    UpdateProfileView(
        authViewModel: AuthViewModel(),
        profileViewModel: ProfileViewModel()
    )
    .preferredColorScheme(.light)
}

#Preview("Dark Theme") {
    UpdateProfileView(
        authViewModel: AuthViewModel(),
        profileViewModel: ProfileViewModel()
    )
    .preferredColorScheme(.dark)
}
