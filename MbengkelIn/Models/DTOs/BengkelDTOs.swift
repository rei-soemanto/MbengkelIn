//
//  BengkelDTOs.swift
//  MbengkelIn
//
//  Created by Rei Soemanto on 27/05/26.
//

import Foundation

// Used by BengkelRepository for name/address/coordinate updates
struct BengkelUpdatePayload: Encodable {
    let name: String
    let address: String
    let latitude: Double
    let longitude: Double
}

// Used by BengkelRepository for offered_services array updates
struct BengkelServicesUpdatePayload: Encodable {
    let offered_services: [BengkelService]
}
