//
//  Vehicle.swift
//  BengkelIn
//
//  Created by Rei Soemanto on 23/04/26.
//

import FirebaseFirestore

struct Vehicle: Codable, Identifiable {
    @DocumentID var id: String?
    var customerId: String 
    var manufacturer: String
    var model: String
    var year: Int
    var licensePlate: String
    var color: String
    @ServerTimestamp var createdAt: Date?
}
