//
//  RupiahText.swift
//  MbengkelIn
//
//  Created by Bryan Fernando Dinata on 28/05/26.
//

import SwiftUI

enum Rupiah {
    static func format(_ amount: Int) -> String {
        format(NSNumber(value: amount))
    }

    static func format(_ amount: Double) -> String {
        format(NSNumber(value: amount))
    }

    private static func format(_ amount: NSNumber) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "IDR"
        formatter.locale = Locale(identifier: "id_ID")
        formatter.maximumFractionDigits = 0
        return formatter.string(from: amount) ?? "Rp 0"
    }
}
