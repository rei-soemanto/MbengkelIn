//
//  BengkelService.swift
//  BengkelIn
//
//  Created by Rei Soemanto on 23/04/26.
//

import Foundation

struct BengkelService: Codable, Identifiable, Hashable {
    var id: String = UUID().uuidString
    var serviceName: String
    var description: String
    var isActive: Bool
    
    enum CodingKeys: String, CodingKey {
        case id
        case serviceName = "service_name"
        case description
        case isActive = "is_active"
    }
}
