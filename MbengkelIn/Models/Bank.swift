//
//  Bank.swift
//  MbengkelIn
//
//  Created by Bryan on 28/05/26.
//

import Foundation

// Static reference data for common Indonesian banks and their account-number
// length(s). Lengths reflect the most common formats per bank.
struct IndonesianBank: Identifiable, Hashable {
    let id: String
    let name: String
    let accountLengths: [Int]

    static let all: [IndonesianBank] = [
        .init(id: "bca", name: "BCA", accountLengths: [10]),
        .init(id: "mandiri", name: "Mandiri", accountLengths: [13]),
        .init(id: "bri", name: "BRI", accountLengths: [15]),
        .init(id: "bni", name: "BNI", accountLengths: [10]),
        .init(id: "bsi", name: "BSI", accountLengths: [10]),
        .init(id: "cimb", name: "CIMB Niaga", accountLengths: [13]),
        .init(id: "permata", name: "Permata", accountLengths: [10, 16]),
        .init(id: "danamon", name: "Danamon", accountLengths: [10]),
        .init(id: "btn", name: "BTN", accountLengths: [16]),
        .init(id: "ocbc", name: "OCBC NISP", accountLengths: [12]),
        .init(id: "panin", name: "Panin", accountLengths: [10]),
        .init(id: "jago", name: "Bank Jago", accountLengths: [10]),
        .init(id: "seabank", name: "SeaBank", accountLengths: [12, 14])
    ]

    static func named(_ name: String) -> IndonesianBank? {
        all.first { $0.name.caseInsensitiveCompare(name) == .orderedSame }
    }

    func isValidAccountNumber(_ accountNumber: String) -> Bool {
        accountNumber.allSatisfy { $0.isNumber } && accountLengths.contains(accountNumber.count)
    }

    var lengthDescription: String {
        if accountLengths.count == 1 {
            return "\(accountLengths[0]) digit"
        }
        return accountLengths.map(String.init).joined(separator: " atau ") + " digit"
    }
}
