//
//  Withdrawal.swift
//  MbengkelIn
//
//  Created by Bryan on 28/05/26.
//

import Foundation

struct Withdrawal: Codable, Identifiable {
    var id: String?
    var userId: String
    var amount: Double
    var bankName: String?
    var bankAccountNumber: String?
    var bankAccountName: String?
    var status: String
    var notes: String?
    var createdAt: Date?
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case amount
        case bankName = "bank_name"
        case bankAccountNumber = "bank_account_number"
        case bankAccountName = "bank_account_name"
        case status
        case notes
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
