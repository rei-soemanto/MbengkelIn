//
//  OrderLocation.swift
//  MbengkelIn
//
//  Created by Amadeus Eugine Dirgantara on 29/05/26.
//

import Foundation

// Live location of the assigned bengkel for an in-progress order
// (order_locations table).
struct OrderLocation: Codable, Identifiable {
    var serviceRequestId: String
    var providerUid: String?
    var latitude: Double
    var longitude: Double
    var updatedAt: String?

    var id: String { serviceRequestId }

    enum CodingKeys: String, CodingKey {
        case serviceRequestId = "service_request_id"
        case providerUid = "provider_uid"
        case latitude
        case longitude
        case updatedAt = "updated_at"
    }
}
