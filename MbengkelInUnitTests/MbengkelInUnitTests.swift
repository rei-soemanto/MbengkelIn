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

    func testMinPriceForAllCases() {
        XCTAssertEqual(ServiceType.banGembos.minPrice, 25000)
        XCTAssertEqual(ServiceType.banPecah.minPrice, 40000)
        XCTAssertEqual(ServiceType.akiKering.minPrice, 60000)
        XCTAssertEqual(ServiceType.mogokMesinMati.minPrice, 50000)
        XCTAssertEqual(ServiceType.gantiBanSerep.minPrice, 30000)
        XCTAssertEqual(ServiceType.rantaiMotorLepas.minPrice, 25000)
        XCTAssertEqual(ServiceType.mesinOverheat.minPrice, 35000)
    }

    func testRequiresTireCount() {
        XCTAssertTrue(ServiceType.banGembos.requiresTireCount)
        XCTAssertTrue(ServiceType.banPecah.requiresTireCount)
        let others = ServiceType.allCases.filter { $0 != .banGembos && $0 != .banPecah }
        for type in others {
            XCTAssertFalse(type.requiresTireCount)
        }
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
