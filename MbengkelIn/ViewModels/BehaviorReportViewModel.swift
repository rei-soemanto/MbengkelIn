//
//  BehaviorReportViewModel.swift
//  MbengkelIn
//
//  Created by Eugene on 02/06/26.
//

import SwiftUI
import Combine
import Supabase

@MainActor
class BehaviorReportViewModel: ObservableObject {
    @Published var isSubmitting = false
    @Published var errorMessage: String?

    private let repository = BehaviorReportRepository()
    private let authService = AuthService()

    func submit(serviceRequestId: String, reason: String) async -> Bool {
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }
        guard let session = try? await authService.getCurrentSession() else {
            errorMessage = "Sesi tidak ditemukan."
            return false
        }
        let uid = session.user.id.uuidString.lowercased()
        do {
            try await repository.submit(serviceRequestId: serviceRequestId, reporterId: uid, reason: reason)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
