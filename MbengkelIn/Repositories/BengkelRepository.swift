//
//  BengkelRepository.swift
//  MbengkelIn
//
//  Created by Rei Soemanto on 27/05/26.
//

import Foundation
import Supabase

class BengkelRepository {
    func fetchBengkel(providerUid: String) async throws -> Bengkel {
        return try await supabase.from("bengkels")
            .select()
            .eq("provider_uid", value: providerUid)
            .single()
            .execute()
            .value
    }
    
    func insertBengkel(_ bengkel: Bengkel) async throws {
        try await supabase.from("bengkels")
            .insert(bengkel)
            .execute()
    }
    
    func updateBengkel(bengkelId: String, payload: BengkelUpdatePayload) async throws {
        try await supabase.from("bengkels")
            .update(payload)
            .eq("id", value: bengkelId)
            .execute()
    }
    
    func updateServices(bengkelId: String, payload: BengkelServicesUpdatePayload) async throws {
        try await supabase.from("bengkels")
            .update(payload)
            .eq("id", value: bengkelId)
            .execute()
    }
    
    func deleteBengkel(bengkelId: String) async throws {
        try await supabase.from("bengkels")
            .delete()
            .eq("id", value: bengkelId)
            .execute()
    }
}
