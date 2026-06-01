//
//  BengkelService.swift
//  MbengkelIn
//
//  Created by Rei Soemanto on 23/04/26.
//

import Foundation

enum ServiceType: String, Codable, CaseIterable {
    case banGembos = "Ban Gembos"
    case banPecah = "Ban Pecah"
    case akiKering = "Aki Kering"
    case mogokMesinMati = "Mogok / Mesin Mati"
    case gantiBanSerep = "Ganti Ban Serep"
    case rantaiMotorLepas = "Rantai Motor Lepas"
    case mesinOverheat = "Mesin Overheat"

    var minPrice: Int {
        switch self {
        case .banGembos: return 25000
        case .banPecah: return 40000
        case .akiKering: return 60000
        case .mogokMesinMati: return 50000
        case .gantiBanSerep: return 30000
        case .rantaiMotorLepas: return 25000
        case .mesinOverheat: return 35000
        }
    }

    var requiresTireCount: Bool {
        self == .banGembos || self == .banPecah
    }

    var iconName: String {
        switch self {
        case .banGembos, .banPecah, .gantiBanSerep: return "car.side.rear.open.fill"
        case .akiKering: return "minus.plus.batteryblock.fill"
        case .mogokMesinMati: return "engine.combustion.fill"
        case .rantaiMotorLepas: return "gearshape.2.fill"
        case .mesinOverheat: return "thermometer.high"
        }
    }
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
