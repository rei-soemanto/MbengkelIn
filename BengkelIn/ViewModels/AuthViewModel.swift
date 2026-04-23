//
//  AuthViewModel.swift
//  BengkelIn
//
//  Created by Rei Soemanto on 23/04/26.
//

import Combine
import SwiftUI
import FirebaseAuth
import FirebaseFirestore

@MainActor
class AuthViewModel: ObservableObject {
    @Published var userSession: FirebaseAuth.User?
    @Published var currentUser: User?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    
    init() {
        self.userSession = Auth.auth().currentUser
        if self.userSession != nil {
            Task { await fetchUser() }
        }
    }
    
    func loginWithEmail(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        successMessage = nil
        
        do {
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            
            if !result.user.isEmailVerified {
                self.errorMessage = "Please verify your email address before logging in."
                try Auth.auth().signOut()
                self.userSession = nil
            } else {
                self.userSession = result.user
                await fetchUser()
            }
        } catch {
            self.errorMessage = error.localizedDescription
        }
        isLoading = false
    }
    
    func registerWithEmail(email: String, password: String, name: String, phoneNumber: String) async {
        isLoading = true
        errorMessage = nil
        successMessage = nil
        
        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            
            let newUser = User(
                id: result.user.uid,
                role: "USER",
                name: name,
                email: email,
                phoneNumber: phoneNumber,
                profileImageUrl: nil,
                balance: 0.0
            )
            
            try Firestore.firestore().collection("users").document(result.user.uid).setData(from: newUser)
            
            try await result.user.sendEmailVerification()
            
            try Auth.auth().signOut()
            self.userSession = nil
            
            self.successMessage = "Registration successful! Please check your email to verify your account."
            
        } catch {
            self.errorMessage = error.localizedDescription
        }
        isLoading = false
    }
    
    func fetchUser() async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        do {
            self.currentUser = try await Firestore.firestore().collection("users").document(uid).getDocument(as: User.self)
        } catch {
            print("Failed to fetch user profile: \(error)")
        }
    }
    
    func signOut() {
        do {
            try Auth.auth().signOut()
            self.userSession = nil
            self.currentUser = nil
        } catch {
            print("Failed to sign out")
        }
    }
}
