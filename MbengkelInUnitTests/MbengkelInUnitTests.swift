import Testing
@testable import MbengkelIn

@Suite("ServiceType")
struct ServiceTypeTests {
    @Test func rawValueRoundTrip() {
        #expect(ServiceType(rawValue: "Aki Kering") == .akiKering)
        #expect(ServiceType.banPecah.rawValue == "Ban Pecah")
        #expect(ServiceType.banGembos.rawValue == "Ban Gembos")
    }

    @Test func unknownRawValue() {
        #expect(ServiceType(rawValue: "nope") == nil)
    }

    @Test func allCasesCount() {
        #expect(ServiceType.allCases.count == 7)
    }

    @Test func minPriceForAllCases() {
        #expect(ServiceType.banGembos.minPrice == 25000)
        #expect(ServiceType.banPecah.minPrice == 40000)
        #expect(ServiceType.akiKering.minPrice == 60000)
        #expect(ServiceType.mogokMesinMati.minPrice == 50000)
        #expect(ServiceType.gantiBanSerep.minPrice == 30000)
        #expect(ServiceType.rantaiMotorLepas.minPrice == 25000)
        #expect(ServiceType.mesinOverheat.minPrice == 35000)
    }

    @Test func requiresTireCount() {
        #expect(ServiceType.banGembos.requiresTireCount)
        #expect(ServiceType.banPecah.requiresTireCount)
        let others = ServiceType.allCases.filter { $0 != .banGembos && $0 != .banPecah }
        for type in others {
            #expect(!type.requiresTireCount)
        }
    }
}

@Suite("Formatting")
struct FormattingTests {
    @Test func formatIntHasRpPrefixAndDigits() {
        let out = Rupiah.format(25000)
        #expect(out.hasPrefix("Rp"))
        #expect(String(out.filter(\.isNumber)) == "25000")
    }

    @Test func formatZero() {
        #expect(Rupiah.format(0).hasPrefix("Rp"))
    }

    @Test func formatDoubleDigits() {
        let out = Rupiah.format(1250000.0)
        #expect(out.hasPrefix("Rp"))
        #expect(String(out.filter(\.isNumber)) == "1250000")
    }
}
