//
//  User.swift
//  MbengkelIn
//
//  Created by Rei Soemanto on 23/04/26.
//

import Foundation

struct User: Codable, Identifiable {
    var id: String
    var name: String
    var profileImageUrl: String?
    var balance: Double
    var heldBalance: Double?
    var pendingBalance: Double?
    var email: String?
    var phoneNumber: String?
    var role: String
    var bankName: String?
    var bankAccountNumber: String?
    var bankAccountName: String?

    var availableBalance: Double {
        balance - (heldBalance ?? 0)
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case profileImageUrl = "profile_image_url"
        case balance
        case heldBalance = "held_balance"
        case pendingBalance = "pending_balance"
        case role
        case bankName = "bank_name"
        case bankAccountNumber = "bank_account_number"
        case bankAccountName = "bank_account_name"
    }
}
