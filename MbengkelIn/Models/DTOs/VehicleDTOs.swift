//
//  VehicleDTOs.swift
//  MbengkelIn
//
//  Created by Rei Soemanto on 27/05/26.
//

import Foundation

struct VehicleUpdatePayload: Encodable {
    let manufacturer: String
    let model: String
    let year: Int
    let license_plate: String
    let color: String
}
