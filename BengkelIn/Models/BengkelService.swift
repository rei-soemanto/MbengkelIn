//
//  BengkelService.swift
//  BengkelIn
//
//  Created by Rei Soemanto on 23/04/26.
//

import Foundation

enum ServiceType: String, Codable, CaseIterable {
    case flatTire = "Flat Tire"
    case accuProblem = "Accu Problem"
    case oilChange = "Oil Change"
    case engineOverheat = "Engine Overheat"
    case towing = "Towing"
    case brakeService = "Brake Service"
    case generalCheckup = "General Checkup"
    case other = "Other"
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
