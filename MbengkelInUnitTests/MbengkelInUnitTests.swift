//
//  MbengkelInUnitTests.swift
//  MbengkelInUnitTests
//

import XCTest
@testable import MbengkelIn

final class ServiceTypeTests: XCTestCase {
    func testRawValueRoundTrip() {
        XCTAssertEqual(ServiceType(rawValue: "Aki Kering"), .akiKering)
        XCTAssertEqual(ServiceType.banPecah.rawValue, "Ban Pecah")
        XCTAssertEqual(ServiceType.banGembos.rawValue, "Ban Gembos")
    }

    func testUnknownRawValue() {
        XCTAssertNil(ServiceType(rawValue: "nope"))
    }

    func testAllCasesCount() {
        XCTAssertEqual(ServiceType.allCases.count, 7)
    }
}

final class FormattingTests: XCTestCase {
    func testFormatIntHasRpPrefixAndDigits() {
        let out = Rupiah.format(25000)
        XCTAssertTrue(out.hasPrefix("Rp"))
        XCTAssertEqual(String(out.filter(\.isNumber)), "25000")
    }

    func testFormatZero() {
        XCTAssertTrue(Rupiah.format(0).hasPrefix("Rp"))
    }

    func testFormatDoubleDigits() {
        let out = Rupiah.format(1250000.0)
        XCTAssertTrue(out.hasPrefix("Rp"))
        XCTAssertEqual(String(out.filter(\.isNumber)), "1250000")
    }
}
