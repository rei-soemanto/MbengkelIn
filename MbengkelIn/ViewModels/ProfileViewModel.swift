//
//  ProfileViewModel.swift
//  MbengkelIn
//
//  Created by Rei Soemanto on 24/04/26.
//

import SwiftUI
import Combine
import Supabase

@MainActor
class ProfileViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    
    private let authService = AuthService()
    private let userRepository = UserRepository()
    private let storageService = StorageService()
    
    func updateProfile(name: String, phoneNumber: String) async -> Bool {
        isLoading = true
        errorMessage = nil
        successMessage = nil
        
        guard let session = try? await authService.getCurrentSession() else {
            self.errorMessage = "Pengguna belum terautentikasi."
            isLoading = false
            return false
        }
        let uid = session.user.id.uuidString.lowercased()
        
        let payload = ProfileUpdatePayload(name: name, phone_number: phoneNumber)
        
        do {
            try await userRepository.updateProfile(uid: uid, payload: payload)
            
            self.successMessage = "Profil berhasil diperbarui!"
            isLoading = false
            return true
            
        } catch {
            self.errorMessage = error.localizedDescription
            isLoading = false
            return false
        }
    }
    
    func uploadProfileImage(_ data: Data) async -> Bool {
        isLoading = true
        errorMessage = nil

        do {
            guard let session = try? await authService.getCurrentSession() else {
                self.errorMessage = "Anda harus masuk untuk mengunggah gambar."
                isLoading = false
                return false
            }
            let uid = session.user.id.uuidString.lowercased()

            let compressed = ImageCompressor.compressed(data)
            let publicURLString = try await storageService.uploadAvatar(uid: uid, data: compressed)
            
            let payload = ProfileImageUpdatePayload(profile_image_url: publicURLString)
            try await userRepository.updateProfileImageUrl(uid: uid, payload: payload)
            
            self.successMessage = "Foto profil berhasil diperbarui!"
            isLoading = false
            return true
            
        } catch {
            self.errorMessage = "Gagal mengunggah gambar: \(error.localizedDescription)"
            isLoading = false
            return false
        }
    }
}
