//
//  AuthViewModel.swift
//  BengkelIn
//
//  Created by Rei Soemanto on 23/04/26.
//

import Combine
import SwiftUI
import Supabase

enum AppMode {
    case customer
    case bengkel
}

@MainActor
class AuthViewModel: ObservableObject {
    @Published var userSession: Supabase.User?
    @Published var currentUser: User?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    
    @Published var appMode: AppMode = .customer

    init() {
        Task {
            do {
                let session = try await supabase.auth.session
                self.userSession = session.user
                await fetchUser()
            } catch {
                self.userSession = nil
            }
        }
    }

    func login(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        successMessage = nil
        do {
            let result = try await supabase.auth.signIn(email: email, password: password)
            self.userSession = result.user
            await fetchUser()
        } catch {
            self.errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func signUp(email: String, password: String, name: String, phoneNumber: String) async {
        isLoading = true
        errorMessage = nil
        successMessage = nil
        
        do {
            let result = try await supabase.auth.signUp(
                email: email,
                password: password,
                data: [
                    "name": .string(name),
                    "phone_number": .string(phoneNumber)
                ]
            )
            
            try await supabase.auth.signOut()
            self.userSession = nil
            self.successMessage = "Registration successful! Please check your email to activate account."
            
        } catch {
            self.errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func fetchUser() async {
        guard let sessionUser = self.userSession else { return }
        let uid = sessionUser.id.uuidString.lowercased()
        do {
            var fetchedUser: User = try await supabase.from("users")
                .select()
                .eq("id", value: uid)
                .single()
                .execute()
                .value
            
            fetchedUser.email = sessionUser.email
            
            if case let .string(phoneString) = sessionUser.userMetadata["phone_number"] {
                fetchedUser.phoneNumber = phoneString
            } else {
                fetchedUser.phoneNumber = sessionUser.phone
            }
            
            self.currentUser = fetchedUser
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }
    
    func sendPasswordResetEmail() async {
        guard let email = currentUser?.email else { return }
        do {
            try await supabase.auth.resetPasswordForEmail(email)
            self.successMessage = "Password reset email sent. Please check your inbox."
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }
    
    func deleteAccount(password: String) async {
        isLoading = true
        errorMessage = nil
        guard let sessionUser = self.userSession, let email = sessionUser.email else { return }
        
        do {
            _ = try await supabase.auth.signIn(email: email, password: password)
            
            try await supabase.from("users")
                .delete()
                .eq("id", value: sessionUser.id.uuidString.lowercased())
                .execute()
            
            try await supabase.auth.signOut()
            self.userSession = nil
            self.currentUser = nil
            
        } catch {
            self.errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func signOut() {
        Task {
            do {
                try await supabase.auth.signOut()
                self.userSession = nil
                self.currentUser = nil
            } catch {
                self.errorMessage = error.localizedDescription
            }
        }
    }
}
