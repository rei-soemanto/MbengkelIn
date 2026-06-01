//
//  BehaviorReportRepository.swift
//  MbengkelIn
//
//  Created by Eugene on 02/06/26.
//

import Foundation
import Supabase

class BehaviorReportRepository {
    func submit(serviceRequestId: String, reporterId: String, reason: String) async throws {
        try await supabase.from("behavior_reports")
            .insert(BehaviorReportPayload(
                service_request_id: serviceRequestId,
                reporter_id: reporterId,
                reason: reason
            ))
            .execute()
    }
}
