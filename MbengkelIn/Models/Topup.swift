//
//  Topup.swift
//  MbengkelIn
//
//  Created by Bryan on 28/05/26.
//

import Foundation

struct Topup: Codable, Identifiable {
    var id: String?
    var userId: String
    var orderId: String
    var grossAmount: Double
    var status: String
    var paymentType: String?
    var redirectUrl: String?
    var snapToken: String?
    var createdAt: Date?
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case orderId = "order_id"
        case grossAmount = "gross_amount"
        case status
        case paymentType = "payment_type"
        case redirectUrl = "redirect_url"
        case snapToken = "snap_token"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
