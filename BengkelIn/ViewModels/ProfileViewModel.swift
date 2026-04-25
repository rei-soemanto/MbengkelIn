//
//  ProfileViewModel.swift
//  BengkelIn
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
    
    func updateProfile(name: String, phoneNumber: String) async -> Bool {
        isLoading = true
        errorMessage = nil
        successMessage = nil
        
        guard let session = try? await supabase.auth.session else {
            self.errorMessage = "User not authenticated."
            isLoading = false
            return false
        }
        let uid = session.user.id.uuidString.lowercased()
        
        struct ProfileUpdate: Encodable {
            let name: String
            let phone_number: String
        }
        let updateData = ProfileUpdate(name: name, phone_number: phoneNumber)
        
        do {
            try await supabase.from("users")
                .update(updateData)
                .eq("id", value: uid)
                .execute()
            
            self.successMessage = "Profile updated successfully!"
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
            guard let session = try? await supabase.auth.session else {
                self.errorMessage = "You must be logged in to upload an image."
                isLoading = false
                return false
            }
            let uid = session.user.id.uuidString.lowercased()
            
            let path = "\(uid)/profile.jpg"
            
            let fileOptions = FileOptions(contentType: "image/jpeg", upsert: true)
            
            try await supabase.storage
                .from("avatars")
                .upload(path, data: data, options: fileOptions)
            
            let publicURL = try supabase.storage
                .from("avatars")
                .getPublicURL(path: path)
            
            struct ImageUpdate: Encodable {
                let profile_image_url: String
            }
            let updateData = ImageUpdate(profile_image_url: publicURL.absoluteString)
            
            try await supabase.from("users")
                .update(updateData)
                .eq("id", value: uid)
                .execute()
            
            self.successMessage = "Profile picture updated successfully!"
            isLoading = false
            return true
            
        } catch {
            self.errorMessage = "Failed to upload image: \(error.localizedDescription)"
            isLoading = false
            return false
        }
    }
}
