//
//  PhotonSearchResponse.swift
//  MbengkelIn
//
//  Created by Bryan Fernando Dinata on 19/05/26.
//

import Foundation

struct PhotonSearchResponse: Codable {
    let features: [PhotonSearchFeature]
}

struct PhotonSearchFeature: Codable, Hashable, Identifiable {
    let id = UUID()
    let properties: PhotonSearchProperties
    let geometry: PhotonSearchGeometry
    
    enum CodingKeys: String, CodingKey {
        case properties, geometry
    }
    
    static func == (lhs: PhotonSearchFeature, rhs: PhotonSearchFeature) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

struct PhotonSearchProperties: Codable {
    let osm_id: Int?
    let name: String?
    let street: String?
    let city: String?
    let state: String?
}

struct PhotonSearchGeometry: Codable {
    let coordinates: [Double]
}
