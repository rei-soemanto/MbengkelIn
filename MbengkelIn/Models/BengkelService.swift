//
//  BengkelService.swift
//  MbengkelIn
//
//  Created by Rei Soemanto on 23/04/26.
//

import Foundation

enum ServiceType: String, Codable, CaseIterable {
    case banGembos = "Ban Gembos"
    case akiKering = "Aki Kering"
    case banPecah = "Ban Pecah"
}

struct BengkelService: Codable, Identifiable, Hashable {
    var id: String = UUID().uuidString
    var serviceType: ServiceType 
    var isActive: Bool
    
    enum CodingKeys: String, CodingKey {
        case id
        case serviceType = "service_type"
        case isActive = "is_active"
    }
}
