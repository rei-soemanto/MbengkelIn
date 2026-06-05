//
//  AuthViewModelTests.swift
//  MbengkelInUnitTests
//
//  Login + sign-up (register) flows, driven through mocked Auth + User repo.
//

import Testing
import Foundation
@testable import MbengkelIn

@Suite("AuthViewModel") @MainActor
final class AuthViewModelTests {
    private func makeVM(_ auth: MockAuthService, _ users: MockUserRepository) -> AuthViewModel {
        AuthViewModel(authService: auth, userRepository: users, startObserving: false)
    }

    @Test func loginSuccessSetsSessionAndUser() async {
        let auth = MockAuthService()
        auth.signInResult = .success(AuthFixtures.session(email: "user@example.com"))
        let users = MockUserRepository()
        users.userToReturn = AuthFixtures.appUser(name: "Budi")
        let vm = makeVM(auth, users)

        await vm.login(email: "user@example.com", password: "secret123")

        #expect(vm.userSession != nil)
        #expect(vm.currentUser?.name == "Budi")
        #expect(vm.currentUser?.email == "user@example.com")
        #expect(vm.errorMessage == nil)
        #expect(vm.isLoading == false)
        #expect(auth.signInCallCount == 1)
        #expect(auth.lastSignInEmail == "user@example.com")
        _ = consume vm
        await Task.yield()
    }

    @Test func loginFailureSetsErrorMessageAndNoSession() async {
        let auth = MockAuthService()
        auth.signInResult = .failure(MockError(message: "Email atau kata sandi salah"))
        let users = MockUserRepository()
        let vm = makeVM(auth, users)

        await vm.login(email: "x@y.com", password: "wrong")

        #expect(vm.userSession == nil)
        #expect(vm.currentUser == nil)
        #expect(vm.errorMessage == "Email atau kata sandi salah")
        #expect(vm.isLoading == false)
        _ = consume vm
        await Task.yield()
    }

    @Test func signUpSuccessSignsOutAndReportsSuccess() async {
        let auth = MockAuthService()
        let users = MockUserRepository()
        let vm = makeVM(auth, users)

        await vm.signUp(email: "new@user.com", password: "secret123", name: "Andi", phoneNumber: "0811")

        #expect(auth.signUpCallCount == 1)
        #expect(auth.signOutCallCount == 1)
        #expect(auth.lastSignUpRequest?.email == "new@user.com")
        #expect(auth.lastSignUpRequest?.name == "Andi")
        #expect(auth.lastSignUpRequest?.phoneNumber == "0811")
        #expect(vm.userSession == nil)
        #expect(vm.successMessage != nil)
        #expect(vm.errorMessage == nil)
        #expect(vm.isLoading == false)
        _ = consume vm
        await Task.yield()
    }

    @Test func signUpFailureSetsErrorAndDoesNotSignOut() async {
        let auth = MockAuthService()
        auth.signUpError = MockError(message: "Email sudah terdaftar")
        let users = MockUserRepository()
        let vm = makeVM(auth, users)

        await vm.signUp(email: "dup@user.com", password: "secret123", name: "Andi", phoneNumber: "0811")

        #expect(vm.errorMessage == "Email sudah terdaftar")
        #expect(auth.signOutCallCount == 0)
        #expect(vm.successMessage == nil)
        #expect(vm.isLoading == false)
        _ = consume vm
        await Task.yield()
    }
}
