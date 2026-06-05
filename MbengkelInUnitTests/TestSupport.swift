//
//  TestSupport.swift
//  MbengkelInUnitTests
//
//  Mocks + fixtures that let the ViewModel unit tests exercise
//  Auth/Vehicle/Bengkel logic without touching the live Supabase backend.
//

import Foundation
import Supabase
@testable import MbengkelIn

struct MockError: Error, LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

enum AuthFixtures {
    static let defaultUserId = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    static var defaultUID: String { defaultUserId.uuidString.lowercased() }

    static func session(
        userId: UUID = defaultUserId,
        email: String = "user@example.com",
        phone: String = "081234567890"
    ) -> Session {
        let authUser = Supabase.User(
            id: userId,
            appMetadata: [:],
            userMetadata: ["phone_number": .string(phone)],
            aud: "authenticated",
            email: email,
            createdAt: Date(timeIntervalSince1970: 0),
            updatedAt: Date(timeIntervalSince1970: 0)
        )
        return Session(
            accessToken: "access-token",
            tokenType: "bearer",
            expiresIn: 3600,
            expiresAt: 0,
            refreshToken: "refresh-token",
            user: authUser
        )
    }

    static func appUser(
        id: String = defaultUID,
        name: String = "Budi",
        role: String = "USER"
    ) -> MbengkelIn.User {
        MbengkelIn.User(
            id: id,
            name: name,
            profileImageUrl: nil,
            balance: 0,
            heldBalance: 0,
            pendingBalance: 0,
            email: nil,
            phoneNumber: nil,
            role: role,
            bankName: nil,
            bankAccountNumber: nil,
            bankAccountName: nil
        )
    }
}

final class MockAuthService: AuthServiceProtocol, @unchecked Sendable {
    var sessionToReturn: Session?
    var signInResult: Result<Session, Error>?
    var signUpError: Error?
    var signOutError: Error?
    var resetError: Error?
    var getSessionError: Error?

    private(set) var signInCallCount = 0
    private(set) var signUpCallCount = 0
    private(set) var signOutCallCount = 0
    private(set) var resetCallCount = 0
    private(set) var lastSignUpRequest: SignUpRequest?
    private(set) var lastSignInEmail: String?

    func getCurrentSession() async throws -> Session {
        if let getSessionError { throw getSessionError }
        guard let sessionToReturn else { throw MockError(message: "no session") }
        return sessionToReturn
    }

    func cachedSession() -> Session? { sessionToReturn }

    func authStateChanges() -> AsyncStream<(event: AuthChangeEvent, session: Session?)> {
        AsyncStream { $0.finish() }
    }

    func signIn(email: String, password: String) async throws -> Session {
        signInCallCount += 1
        lastSignInEmail = email
        switch signInResult {
        case .success(let session): return session
        case .failure(let error): throw error
        case .none:
            if let sessionToReturn { return sessionToReturn }
            throw MockError(message: "no signIn result configured")
        }
    }

    func signUp(request: SignUpRequest) async throws {
        signUpCallCount += 1
        lastSignUpRequest = request
        if let signUpError { throw signUpError }
    }

    func signOut() async throws {
        signOutCallCount += 1
        if let signOutError { throw signOutError }
    }

    func resetPassword(email: String) async throws {
        resetCallCount += 1
        if let resetError { throw resetError }
    }
}

final class MockUserRepository: UserRepositoryProtocol, @unchecked Sendable {
    var userToReturn: MbengkelIn.User?
    var fetchError: Error?
    var deleteError: Error?
    private(set) var deleteCallCount = 0

    func fetchUser(uid: String) async throws -> MbengkelIn.User {
        if let fetchError { throw fetchError }
        guard let userToReturn else { throw MockError(message: "no user") }
        return userToReturn
    }

    func deleteUser(uid: String) async throws {
        deleteCallCount += 1
        if let deleteError { throw deleteError }
    }
}

final class MockVehicleRepository: VehicleRepositoryProtocol, @unchecked Sendable {
    var stored: [Vehicle] = []
    var fetchError: Error?
    var insertError: Error?
    var updateError: Error?
    var deleteError: Error?

    private(set) var insertCallCount = 0
    private(set) var updateCallCount = 0
    private(set) var deleteCallCount = 0
    private(set) var lastInserted: Vehicle?
    private(set) var lastUpdatePayload: VehicleUpdatePayload?

    func fetchVehicles(customerId: String) async throws -> [Vehicle] {
        if let fetchError { throw fetchError }
        return stored
    }

    func insertVehicle(_ vehicle: Vehicle) async throws {
        insertCallCount += 1
        lastInserted = vehicle
        if let insertError { throw insertError }
        var inserted = vehicle
        if inserted.id == nil { inserted.id = "generated-\(insertCallCount)" }
        stored.append(inserted)
    }

    func updateVehicle(vehicleId: String, payload: VehicleUpdatePayload) async throws {
        updateCallCount += 1
        lastUpdatePayload = payload
        if let updateError { throw updateError }
    }

    func deleteVehicle(vehicleId: String) async throws {
        deleteCallCount += 1
        if let deleteError { throw deleteError }
        stored.removeAll { $0.id == vehicleId }
    }
}

final class MockBengkelRepository: BengkelRepositoryProtocol, @unchecked Sendable {
    var bengkelToReturn: Bengkel?
    var fetchError: Error?
    var insertError: Error?
    var updateError: Error?
    var updateServicesError: Error?
    var deleteError: Error?

    private(set) var insertCallCount = 0
    private(set) var updateCallCount = 0
    private(set) var updateServicesCallCount = 0
    private(set) var deleteCallCount = 0
    private(set) var lastInserted: Bengkel?
    private(set) var lastUpdatePayload: BengkelUpdatePayload?
    private(set) var lastServicesPayload: BengkelServicesUpdatePayload?

    func fetchBengkel(providerUid: String) async throws -> Bengkel {
        if let fetchError { throw fetchError }
        guard let bengkelToReturn else { throw MockError(message: "no bengkel") }
        return bengkelToReturn
    }

    func insertBengkel(_ bengkel: Bengkel) async throws {
        insertCallCount += 1
        lastInserted = bengkel
        if let insertError { throw insertError }
    }

    func updateBengkel(bengkelId: String, payload: BengkelUpdatePayload) async throws {
        updateCallCount += 1
        lastUpdatePayload = payload
        if let updateError { throw updateError }
    }

    func updateServices(bengkelId: String, payload: BengkelServicesUpdatePayload) async throws {
        updateServicesCallCount += 1
        lastServicesPayload = payload
        if let updateServicesError { throw updateServicesError }
    }

    func deleteBengkel(bengkelId: String) async throws {
        deleteCallCount += 1
        if let deleteError { throw deleteError }
    }
}
