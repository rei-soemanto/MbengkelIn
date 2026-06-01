//
//  AuthService.swift
//  MbengkelIn
//
//  Created by Rei Soemanto on 27/05/26.
//

import Foundation
import Supabase

class AuthService {
    func getCurrentSession() async throws -> Session {
        return try await supabase.auth.session
    }

    // Lowercased Supabase auth user id — the app's user PK convention.
    func currentUID() async throws -> String {
        try await supabase.auth.session.user.id.uuidString.lowercased()
    }

    // Locally-stored session WITHOUT a network refresh — used so a transient
    // network failure at launch doesn't bounce a logged-in user to Login.
    func cachedSession() -> Session? {
        supabase.auth.currentSession
    }

    // Stream of auth events (sign-in, token refresh, sign-out) so the app can
    // keep its session in sync with the SDK.
    func authStateChanges() -> AsyncStream<(event: AuthChangeEvent, session: Session?)> {
        AsyncStream { continuation in
            let task = Task {
                for await change in supabase.auth.authStateChanges {
                    continuation.yield((change.event, change.session))
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
    
    func signIn(email: String, password: String) async throws -> Session {
        return try await supabase.auth.signIn(email: email, password: password)
    }
    
    func signUp(request: SignUpRequest) async throws {
        try await supabase.auth.signUp(
            email: request.email,
            password: request.password,
            data: [
                "name": .string(request.name),
                "phone_number": .string(request.phoneNumber)
            ]
        )
    }
    
    func signOut() async throws {
        try await supabase.auth.signOut()
    }
    
    func resetPassword(email: String) async throws {
        try await supabase.auth.resetPasswordForEmail(email)
    }
}
