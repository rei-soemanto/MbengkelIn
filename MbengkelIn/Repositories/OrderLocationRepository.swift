//
//  OrderLocationRepository.swift
//  MbengkelIn
//
//  Created by Amadeus Eugine Dirgantara on 29/05/26.
//

import Foundation
import Supabase

class OrderLocationRepository {
    func upsertLocation(_ payload: OrderLocationPayload) async throws {
        try await supabase.from("order_locations")
            .upsert(payload, onConflict: "service_request_id")
            .execute()
    }

    func fetchLocation(serviceRequestId: String) async throws -> OrderLocation? {
        let rows: [OrderLocation] = try await supabase.from("order_locations")
            .select()
            .eq("service_request_id", value: serviceRequestId)
            .limit(1)
            .execute()
            .value
        return rows.first
    }

    func upsertCustomerLocation(_ payload: CustomerLocationPayload) async throws {
        try await supabase.from("customer_locations")
            .upsert(payload, onConflict: "service_request_id")
            .execute()
    }

    func fetchCustomerLocation(serviceRequestId: String) async throws -> CustomerLocation? {
        let rows: [CustomerLocation] = try await supabase.from("customer_locations")
            .select()
            .eq("service_request_id", value: serviceRequestId)
            .limit(1)
            .execute()
            .value
        return rows.first
    }
}
