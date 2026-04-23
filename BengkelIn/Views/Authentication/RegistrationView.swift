//
//  RegistrationView.swift
//  BengkelIn
//
//  Created by Rei Soemanto on 23/04/26.
//

import SwiftUI

struct RegistrationView: View {
    @ObservedObject var viewModel: AuthViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var email = ""
    @State private var password = ""
    @State private var name = ""
    @State private var phoneNumber = ""
    
    var body: some View {
        ZStack {
            VStack(spacing: 20) {
                Text("Create Account")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 10)
                
                CustomInputField(iconName: "person", placeholder: "Full Name", text: $name)
                
                CustomInputField(iconName: "phone", placeholder: "Phone Number", text: $phoneNumber)
                    .keyboardType(.phonePad)
                
                CustomInputField(iconName: "envelope", placeholder: "Email", text: $email)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                
                CustomInputField(iconName: "lock", placeholder: "Password", text: $password, isSecure: true)
                
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.footnote)
                        .multilineTextAlignment(.center)
                }
                
                Button {
                    Task {
                        await viewModel.registerWithEmail(email: email, password: password, name: name, phoneNumber: phoneNumber)
                        
                        if viewModel.errorMessage == nil {
                            dismiss()
                        }
                    }
                } label: {
                    Text("Sign Up")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 55)
                        .background(Color.blue)
                        .cornerRadius(12)
                }
                .padding(.top, 12)
                .disabled(viewModel.isLoading)
                
                Spacer()
                
                Button { dismiss() } label: {
                    HStack(spacing: 4) {
                        Text("Already have an account?")
                            .foregroundColor(.gray)
                        Text("Sign In")
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                    }
                    .font(.footnote)
                }
            }
            .padding()
            
            if viewModel.isLoading {
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
