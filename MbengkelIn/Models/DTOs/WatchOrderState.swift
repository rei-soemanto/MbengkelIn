//
//  WatchOrderState.swift
//  MbengkelIn
//
//  Created by Rei Soemanto on 29/05/26.
//

import Foundation

// Snapshot of the customer's single active order, pushed phone -> watch over
// WatchConnectivity (encoded to JSON and sent via updateApplicationContext).
// An identical copy lives in the watch target — the two targets share no files,
// so this small DTO is intentionally duplicated.
struct WatchOrderState: Codable, Equatable {
    var hasActiveOrder: Bool
    // "finding" (To Do) | "inProgress" (On Progress) | "finished" (Done)
    var stage: String
    var serviceType: String?
    var bengkelName: String?
    var agreedPrice: Int?
    var mySideCompleted: Bool
    var alreadyRated: Bool
    var requestId: String?
    var offers: [WatchBidOffer]

    static let empty = WatchOrderState(
        hasActiveOrder: false, stage: "finding", serviceType: nil,
        bengkelName: nil, agreedPrice: nil, mySideCompleted: false,
        alreadyRated: false, requestId: nil, offers: []
    )
}

struct WatchBidOffer: Codable, Equatable, Identifiable {
    var bidId: String
    var bengkelName: String
    var price: Int
    var rating: Double?
    var id: String { bidId }
}
