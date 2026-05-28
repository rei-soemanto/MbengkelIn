//
//  UserRepository.swift
//  MbengkelIn
//
//  Created by Rei Soemanto on 27/05/26.
//

import Foundation
import Supabase

class UserRepository {
    func fetchUser(uid: String) async throws -> User {
        return try await supabase.from("users")
            .select()
            .eq("id", value: uid)
            .single()
            .execute()
            .value
    }
    
    func updateProfile(uid: String, payload: ProfileUpdatePayload) async throws {
        try await supabase.from("users")
            .update(payload)
            .eq("id", value: uid)
            .execute()
    }
    
    func updateProfileImageUrl(uid: String, payload: ProfileImageUpdatePayload) async throws {
        try await supabase.from("users")
            .update(payload)
            .eq("id", value: uid)
            .execute()
    }
    
    func updateBankDetails(uid: String, payload: BankDetailsUpdatePayload) async throws {
        try await supabase.from("users")
            .update(payload)
            .eq("id", value: uid)
            .execute()
    }
    
    func deleteUser(uid: String) async throws {
        try await supabase.from("users")
            .delete()
            .eq("id", value: uid)
            .execute()
    }
}
