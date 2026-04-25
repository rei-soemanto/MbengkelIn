//
//  User.swift
//  BengkelIn
//
//  Created by Rei Soemanto on 23/04/26.
//

import Foundation

struct User: Codable, Identifiable {
    var id: String
    var name: String
    var profileImageUrl: String?
    var balance: Double
    var email: String?
    var phoneNumber: String?
    var role: String

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case profileImageUrl = "profile_image_url"
        case balance
        case role
    }
}
