//
//  AuthViewModel.swift
//  MbengkelIn
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
    @Published var isInitializing = true
    @Published var errorMessage: String?
    @Published var successMessage: String?
    
    @Published var appMode: AppMode = .customer
    
    private let authService = AuthService()
    private let userRepository = UserRepository()
    private var authStateTask: Task<Void, Never>?

    init() {
        Task { await loadInitialSession() }
        authStateTask = Task { [weak self] in
            guard let self else { return }
            for await change in self.authService.authStateChanges() {
                switch change.event {
                case .signedOut:
                    self.userSession = nil
                    self.currentUser = nil
                case .signedIn, .tokenRefreshed, .initialSession:
                    if let user = change.session?.user { self.userSession = user }
                default:
                    break
                }
            }
        }
    }

    deinit { authStateTask?.cancel() }

    func loadInitialSession() async {
        isInitializing = true
        defer { isInitializing = false }
        do {
            let session = try await authService.getCurrentSession()
            self.userSession = session.user
            await fetchUser()
        } catch {
            if let cached = authService.cachedSession() {
                self.userSession = cached.user
                await fetchUser()
            } else {
                self.userSession = nil
            }
        }
    }

    func login(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        successMessage = nil
        do {
            let session = try await authService.signIn(email: email, password: password)
            self.userSession = session.user
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
            try await authService.signUp(request: SignUpRequest(
                email: email,
                password: password,
                name: name,
                phoneNumber: phoneNumber
            ))
            
            try await authService.signOut()
            self.userSession = nil
            self.successMessage = "Pendaftaran berhasil! Silakan periksa email Anda untuk mengaktifkan akun."
            
        } catch {
            self.errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func fetchUser() async {
        guard let sessionUser = self.userSession else { return }
        let uid = sessionUser.id.uuidString.lowercased()
        do {
            var fetchedUser = try await userRepository.fetchUser(uid: uid)

            fetchedUser.email = sessionUser.email

            if case let .string(phoneString) = sessionUser.userMetadata["phone_number"] {
                fetchedUser.phoneNumber = phoneString
            } else {
                fetchedUser.phoneNumber = sessionUser.phone
            }

            self.currentUser = fetchedUser
        } catch {
            if (error as? PostgrestError)?.code == "PGRST116" {
                try? await authService.signOut()
                self.userSession = nil
                self.currentUser = nil
            } else {
                self.errorMessage = error.localizedDescription
            }
        }
    }
    
    func sendPasswordResetEmail() async {
        guard let email = currentUser?.email else { return }
        do {
            try await authService.resetPassword(email: email)
            self.successMessage = "Email reset kata sandi terkirim. Silakan periksa kotak masuk Anda."
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }
    
    func deleteAccount(password: String) async {
        isLoading = true
        errorMessage = nil
        guard let sessionUser = self.userSession, let email = sessionUser.email else { isLoading = false; return }
        
        do {
            _ = try await authService.signIn(email: email, password: password)
            
            try await userRepository.deleteUser(uid: sessionUser.id.uuidString.lowercased())
            
            try await authService.signOut()
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
                try await authService.signOut()
                self.userSession = nil
                self.currentUser = nil
            } catch {
                self.errorMessage = error.localizedDescription
            }
        }
    }
}
