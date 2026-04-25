//
//  Bengkel.swift
//  BengkelIn
//
//  Created by Rei Soemanto on 23/04/26.
//

import Foundation

struct Bengkel: Codable, Identifiable {
    var id: String?
    var providerUid: String
    var name: String
    var address: String
    
    // Geospatial data for the map queries
    var latitude: Double
    var longitude: Double
    
    // Status for manual Admin Verification
    var status: String // Defaults to "Pending", manually change to "Verified"
    
    // The embedded services array (Stored as JSONB in Supabase)
    var offeredServices: [BengkelService]
    
    // Rating aggregates
    var averageRating: Double
    var totalReviews: Int
    
    var createdAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case providerUid = "provider_uid"
        case name
        case address
        case latitude
        case longitude
        case status
        case offeredServices = "offered_services"
        case averageRating = "average_rating"
        case totalReviews = "total_reviews"
        case createdAt = "created_at"
    }
}
