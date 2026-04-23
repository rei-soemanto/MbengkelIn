//
//  User.swift
//  BengkelIn
//
//  Created by Rei Soemanto on 23/04/26.
//

import FirebaseFirestore

struct User: Codable, Identifiable {
    @DocumentID var id: String?
    var role: String
//    var name: String
//    var email: String
//    var phoneNumber: String
//    var profileImageUrl: String?
    var balance: Double
    @ServerTimestamp var createdAt: Date?
}
