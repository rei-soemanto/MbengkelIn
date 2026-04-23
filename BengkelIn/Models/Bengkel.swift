//
//  Bengkel.swift
//  BengkelIn
//
//  Created by Rei Soemanto on 23/04/26.
//

import FirebaseFirestore

struct Bengkel: Codable, Identifiable {
    @DocumentID var id: String?
    var providerUid: String 
    var name: String
    var address: String
    
    // Geospatial data for the map queries
    var latitude: Double
    var longitude: Double
    
    // Status for manual Admin Verification
    var status: String // Defaults to "Pending", manually change to "Verified"
    
    // The embedded services array
    var offeredServices: [BengkelService] 
    
    // Array of mechanics linked to this Bengkel
    var mechanicUids: [String] 
    
    // Rating aggregates
    var averageRating: Double
    var totalReviews: Int
    
    @ServerTimestamp var createdAt: Date?
}
