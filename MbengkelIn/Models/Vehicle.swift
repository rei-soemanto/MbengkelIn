//
//  Vehicle.swift
//  MbengkelIn
//
//  Created by Rei Soemanto on 23/04/26.
//

import Foundation

struct Vehicle: Codable, Identifiable {
    var id: String?
    var customerId: String
    var manufacturer: String
    var model: String
    var year: Int
    var licensePlate: String
    var color: String
    var createdAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case customerId = "customer_id"
        case manufacturer
        case model
        case year
        case licensePlate = "license_plate"
        case color
        case createdAt = "created_at"
    }
}
