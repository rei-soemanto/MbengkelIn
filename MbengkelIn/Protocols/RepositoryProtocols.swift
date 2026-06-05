//
//  RepositoryProtocols.swift
//  MbengkelIn
//
//  Created by Rei Soemanto on 05/06/26.
//
//  Abstractions over the table repositories so ViewModels can be unit-tested
//  with in-memory mocks instead of the live Supabase database. Each concrete
//  Repository conforms unchanged via the extensions below; production code uses
//  the real types as init defaults, so no call site changes.

import Foundation

protocol UserRepositoryProtocol {
    func fetchUser(uid: String) async throws -> User
    func deleteUser(uid: String) async throws
}

protocol VehicleRepositoryProtocol {
    func fetchVehicles(customerId: String) async throws -> [Vehicle]
    func insertVehicle(_ vehicle: Vehicle) async throws
    func updateVehicle(vehicleId: String, payload: VehicleUpdatePayload) async throws
    func deleteVehicle(vehicleId: String) async throws
}

protocol BengkelRepositoryProtocol {
    func fetchBengkel(providerUid: String) async throws -> Bengkel
    func insertBengkel(_ bengkel: Bengkel) async throws
    func updateBengkel(bengkelId: String, payload: BengkelUpdatePayload) async throws
    func updateServices(bengkelId: String, payload: BengkelServicesUpdatePayload) async throws
    func deleteBengkel(bengkelId: String) async throws
}

extension UserRepository: UserRepositoryProtocol {}
extension VehicleRepository: VehicleRepositoryProtocol {}
extension BengkelRepository: BengkelRepositoryProtocol {}
