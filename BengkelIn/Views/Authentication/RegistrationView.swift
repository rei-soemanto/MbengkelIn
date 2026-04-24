//
//  RegistrationView.swift
//  BengkelIn
//
//  Created by Rei Soemanto on 23/04/26.
//

import SwiftUI

struct RegistrationView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var email = ""
    @State private var password = ""
    @State private var name = ""
    @State private var phoneNumber = ""
    
    var body: some View {
        ZStack {
            VStack(spacing: 20) {
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
                    Text("BengkelIn")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Professional roadside assistance and mechanical services at your fingertips.")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.bottom, 20)
                
                CustomInputField(iconName: "person", placeholder: "Full Name", text: $name)
                
                CustomInputField(iconName: "phone", placeholder: "Phone Number", text: $phoneNumber)
                    .keyboardType(.phonePad)
                
                CustomInputField(iconName: "envelope", placeholder: "Email", text: $email)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                
                CustomInputField(iconName: "lock", placeholder: "Password", text: $password, isSecure: true)
                
                if let errorMessage = authViewModel.errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.footnote)
                        .multilineTextAlignment(.center)
                }
                
                Button {
                    Task {
                        await authViewModel.signUp(email: email, password: password, name: name, phoneNumber: phoneNumber)
                        
                        if authViewModel.errorMessage == nil {
                            dismiss()
                        }
                    }
                } label: {
                    Text("Sign Up")
                        .font(.headline)
                        .foregroundColor(Color(.systemBackground))
                        .frame(maxWidth: .infinity)
                        .frame(height: 55)
                        .background(Color.primary.opacity(0.9))
                        .cornerRadius(12)
                }
                .padding(.top, 12)
                .disabled(authViewModel.isLoading)
                
                Spacer()
                
                Button { dismiss() } label: {
                    HStack(spacing: 4) {
                        Text("Already have an account?")
                            .foregroundColor(.gray)
                        Text("Sign In")
                            .fontWeight(.bold)
                            .foregroundColor(Color.primary.opacity(0.9))
                    }
                    .font(.footnote)
                }
            }
            .padding()
            
            if authViewModel.isLoading {
                ProgressView()
                    .padding()
                    .background(Color.white)
                    .cornerRadius(10)
                    .shadow(radius: 10)
            }
        }
        .navigationBarBackButtonHidden(true)
    }
}

#Preview("Light Theme") {
    RegistrationView(
        authViewModel: AuthViewModel()
    )
    .preferredColorScheme(.light)
}

#Preview("Dark Theme") {
    RegistrationView(
        authViewModel: AuthViewModel()
    )
    .preferredColorScheme(.dark)
}
