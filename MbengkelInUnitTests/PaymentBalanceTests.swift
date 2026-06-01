//
//  PaymentBalanceTests.swift
//  MbengkelInUnitTests
//

import XCTest
@testable import MbengkelIn

// availableBalance must exclude escrowed (held) funds so held money never reads
// as withdrawable — the client mirror of the request_withdrawal RPC's check.
@MainActor
final class PaymentBalanceTests: XCTestCase {
    func testAvailableBalanceSubtractsHeld() {
        let vm = PaymentViewModel()
        vm.balance = 100_000
        vm.heldBalance = 30_000
        XCTAssertEqual(vm.availableBalance, 70_000, accuracy: 0.0001)
    }

    func testAvailableBalanceClampsAtZero() {
        let vm = PaymentViewModel()
        vm.balance = 10_000
        vm.heldBalance = 50_000
        XCTAssertEqual(vm.availableBalance, 0, accuracy: 0.0001)
    }

    func testAvailableBalanceEqualsBalanceWhenNoHold() {
        let vm = PaymentViewModel()
        vm.balance = 42_000
        vm.heldBalance = 0
        XCTAssertEqual(vm.availableBalance, 42_000, accuracy: 0.0001)
    }

    func testHasBankDetails() {
        let vm = PaymentViewModel()
        XCTAssertFalse(vm.hasBankDetails)
        vm.bankName = "BCA"
        vm.bankAccountNumber = "123"
        vm.bankAccountName = "Budi"
        XCTAssertTrue(vm.hasBankDetails)
    }
}
