//
//  LoginView.swift
//  MbengkelIn
//
//  Created by Rei Soemanto on 23/04/26.
//

import SwiftUI

struct LoginView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @State private var email = ""
    @State private var password = ""
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground).ignoresSafeArea()
                
                VStack(spacing: 24) {
                    ZStack {
                        Rectangle()
                            .fill(Color.primary.opacity(0.9))
                            .frame(width: 120, height: 120)
                            .cornerRadius(20)
                        
                        Image(systemName: "briefcase.fill")
                            .font(.largeTitle)
                            .foregroundColor(Color(.systemBackground))
                    }
                    .padding(.top, 30)
                    
                    VStack(alignment: .center, spacing: 8) {
                        Text("MbengkelIn")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("Bantuan darurat di jalan dan layanan bengkel profesional dalam genggaman Anda.")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.bottom, 20)
                    
                    if let errorMessage = authViewModel.errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.footnote)
                            .multilineTextAlignment(.center)
                    }
                    
                    if let successMessage = authViewModel.successMessage {
                        Text(successMessage)
                            .foregroundColor(.green)
                            .font(.footnote)
                            .multilineTextAlignment(.center)
                    }
                    
                    VStack(spacing: 16) {
                        CustomInputField(iconName: "envelope", placeholder: "Email", text: $email)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                        
                        CustomInputField(iconName: "lock", placeholder: "Password", text: $password, isSecure: true)
                    }
                    
                    Button {
                        Task { await authViewModel.login(email: email, password: password) }
                    } label: {
                        Text("Masuk")
                            .font(.headline)
                            .foregroundColor(Color(.systemBackground))
                            .frame(maxWidth: .infinity)
                            .frame(height: 55)
                            .background(Color.primary.opacity(0.9))
                            .cornerRadius(12)
                    }
                    .disabled(authViewModel.isLoading)
                    
                    Spacer()
                    
                    NavigationLink(destination: RegistrationView(authViewModel: authViewModel)) {
                        HStack(spacing: 4) {
                            Text("Belum punya akun?")
                                .foregroundColor(.gray)
                            Text("Daftar")
                                .fontWeight(.bold)
                                .foregroundColor(Color.primary.opacity(0.9))
                        }
                        .font(.footnote)
                    }
                }
                .padding(.horizontal, 24)
            }
            .overlay {
                if authViewModel.isLoading {
                    ProgressView()
                        .padding()
                        .background(Color.white)
                        .cornerRadius(10)
                        .shadow(radius: 10)
                }
            }
        }
    }
}

#Preview("Light Theme") {
    LoginView(
        authViewModel: AuthViewModel()
    )
    .preferredColorScheme(.light)
}

#Preview("Dark Theme") {
    LoginView(
        authViewModel: AuthViewModel()
    )
    .preferredColorScheme(.dark)
}
