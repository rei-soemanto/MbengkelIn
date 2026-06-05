//
//  AuthServiceProtocol.swift
//  MbengkelIn
//
//  Created by Rei Soemanto on 05/06/26.
//

import Foundation
import Supabase

// Abstraction over AuthService so ViewModels can be unit-tested with a mock
// instead of hitting the live Supabase Auth SDK. AuthService itself conforms
// unchanged (see the extension below); production call sites use the default.
protocol AuthServiceProtocol {
    func getCurrentSession() async throws -> Session
    func cachedSession() -> Session?
    func authStateChanges() -> AsyncStream<(event: AuthChangeEvent, session: Session?)>
    func signIn(email: String, password: String) async throws -> Session
    func signUp(request: SignUpRequest) async throws
    func signOut() async throws
    func resetPassword(email: String) async throws
}

extension AuthService: AuthServiceProtocol {}
