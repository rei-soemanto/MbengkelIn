import Testing
@testable import MbengkelIn

@Suite("PaymentBalance") @MainActor
final class PaymentBalanceTests {
    @Test func availableBalanceSubtractsHeld() async {
        let vm = PaymentViewModel()
        vm.balance = 100_000
        vm.heldBalance = 30_000
        #expect(abs(vm.availableBalance - 70_000) < 0.0001)
        _ = consume vm
        await Task.yield()
    }

    @Test func availableBalanceClampsAtZero() async {
        let vm = PaymentViewModel()
        vm.balance = 10_000
        vm.heldBalance = 50_000
        #expect(abs(vm.availableBalance - 0) < 0.0001)
        _ = consume vm
        await Task.yield()
    }

    @Test func availableBalanceEqualsBalanceWhenNoHold() async {
        let vm = PaymentViewModel()
        vm.balance = 42_000
        vm.heldBalance = 0
        #expect(abs(vm.availableBalance - 42_000) < 0.0001)
        _ = consume vm
        await Task.yield()
    }

    @Test func hasBankDetails() async {
        let vm = PaymentViewModel()
        #expect(!vm.hasBankDetails)
        vm.bankName = "BCA"
        vm.bankAccountNumber = "123"
        vm.bankAccountName = "Budi"
        #expect(vm.hasBankDetails)
        _ = consume vm
        await Task.yield()
    }
}
