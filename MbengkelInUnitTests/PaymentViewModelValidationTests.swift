//
//  PaymentViewModelValidationTests.swift
//  MbengkelInUnitTests
//
//  Top-up, withdrawal, and resume-topup validation. Each guard returns before
//  the first `await`, so these exercise the money-input rules without hitting
//  the payment edge function or Supabase. (availableBalance / hasBankDetails are
//  covered in PaymentBalanceTests.)
//

import Testing
import Foundation
@testable import MbengkelIn

@Suite("PaymentViewModelValidation") @MainActor
final class PaymentViewModelValidationTests {

    // MARK: Top-up bounds

    @Test func topupBelowMinimumIsRejected() async {
        let vm = PaymentViewModel()
        await vm.startTopup(amount: vm.minTopupAmount - 1)
        #expect(vm.errorMessage?.contains("Minimal top up") == true)
        #expect(vm.paymentTarget == nil)
        #expect(vm.isLoading == false)
        _ = consume vm
        await Task.yield()
    }

    @Test func topupAboveMaximumIsRejected() async {
        let vm = PaymentViewModel()
        await vm.startTopup(amount: vm.maxTopupAmount + 1)
        #expect(vm.errorMessage?.contains("Maksimal top up") == true)
        #expect(vm.paymentTarget == nil)
        _ = consume vm
        await Task.yield()
    }

    // MARK: Withdrawal rules

    @Test func withdrawalBelowMinimumIsRejected() async {
        let vm = PaymentViewModel()
        let ok = await vm.requestWithdrawal(amount: 9_999)
        #expect(ok == false)
        #expect(vm.errorMessage == "Minimal penarikan Rp10.000")
        _ = consume vm
        await Task.yield()
    }

    @Test func withdrawalExceedingBalanceIsRejected() async {
        let vm = PaymentViewModel()
        vm.balance = 20_000
        let ok = await vm.requestWithdrawal(amount: 50_000)
        #expect(ok == false)
        #expect(vm.errorMessage == "Saldo tidak mencukupi.")
        _ = consume vm
        await Task.yield()
    }

    @Test func withdrawalWithoutBankDetailsIsRejected() async {
        let vm = PaymentViewModel()
        vm.balance = 100_000        // enough funds
        // bank fields left empty -> hasBankDetails == false
        let ok = await vm.requestWithdrawal(amount: 50_000)
        #expect(ok == false)
        #expect(vm.errorMessage == "Atur rekening bank terlebih dahulu.")
        _ = consume vm
        await Task.yield()
    }

    // MARK: Resume top-up (pure)

    private func topup(status: String, redirect: String?) -> Topup {
        Topup(id: "t1", userId: "u1", orderId: "o1", grossAmount: 50_000,
              status: status, paymentType: nil, redirectUrl: redirect,
              snapToken: nil, createdAt: nil, updatedAt: nil)
    }

    @Test func resumePendingTopupOpensPaymentTarget() async {
        let vm = PaymentViewModel()
        vm.resumeTopup(topup(status: "pending", redirect: "https://pay.example/snap/abc"))
        #expect(vm.paymentTarget != nil)
        #expect(vm.currentOrderId == "o1")
        _ = consume vm
        await Task.yield()
    }

    @Test func resumeSettledTopupIsIgnored() async {
        let vm = PaymentViewModel()
        vm.resumeTopup(topup(status: "success", redirect: "https://pay.example/snap/abc"))
        #expect(vm.paymentTarget == nil)
        #expect(vm.currentOrderId == nil)
        _ = consume vm
        await Task.yield()
    }

    @Test func resumePendingTopupWithoutUrlIsIgnored() async {
        let vm = PaymentViewModel()
        vm.resumeTopup(topup(status: "pending", redirect: nil))
        #expect(vm.paymentTarget == nil)
        _ = consume vm
        await Task.yield()
    }
}
