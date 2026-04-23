//
//  LoginView.swift
//  BengkelIn
//
//  Created by Rei Soemanto on 23/04/26.
//

import SwiftUI

struct LoginView: View {
    @ObservedObject var viewModel: AuthViewModel
    @State private var email = ""
    @State private var password = ""
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground).ignoresSafeArea()
                
                VStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Welcome Back")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("Please sign in to MbengkelIn to continue")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 20)
                    
                    if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.footnote)
                            .multilineTextAlignment(.center)
                    }
                    
                    if let successMessage = viewModel.successMessage {
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
                        Task { await viewModel.loginWithEmail(email: email, password: password) }
                    } label: {
                        Text("Sign In")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 55)
                            .background(Color.blue)
                            .cornerRadius(12)
                    }
                    .disabled(viewModel.isLoading)
                    
                    Spacer()
                    
                    NavigationLink(destination: RegistrationView(viewModel: viewModel)) {
                        HStack(spacing: 4) {
                            Text("Don't have an account?")
                                .foregroundColor(.gray)
                            Text("Sign Up")
                                .fontWeight(.bold)
                                .foregroundColor(.blue)
                        }
                        .font(.footnote)
                    }
                }
                .padding(.horizontal, 24)
            }
            .overlay {
                if viewModel.isLoading {
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
