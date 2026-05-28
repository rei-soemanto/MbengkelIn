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
