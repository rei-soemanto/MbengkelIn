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
    
    func uploadProfileImage(_ imageData: Data) async -> Bool {
        isLoading = true
        errorMessage = nil
        
        guard let session = try? await supabase.auth.session else {
            self.errorMessage = "User not authenticated."
            isLoading = false
            return false
        }
        
        let uid = session.user.id.uuidString.lowercased()
        let filePath = "\(uid).jpg"
        
        do {
            let _ = try await supabase.storage.from("profile_images").upload(
                path: filePath,
                file: imageData,
                options: FileOptions(contentType: "image/jpeg", upsert: true)
            )
            
            let downloadURL = try supabase.storage.from("profile_images").getPublicURL(path: filePath)
            
            let uniqueURLString = downloadURL.absoluteString + "?v=\(Date().timeIntervalSince1970)"
            
            struct ImageUpdate: Encodable {
                let profile_image_url: String
            }
            let updateData = ImageUpdate(profile_image_url: uniqueURLString)
            
            try await supabase.from("users")
                .update(updateData)
                .eq("id", value: uid)
                .execute()
            
            self.successMessage = "Profile picture updated!"
            isLoading = false
            return true
            
        } catch {
            print("📸 IMAGE UPLOAD ERROR: \(error.localizedDescription)")
            
            self.errorMessage = error.localizedDescription
            isLoading = false
            return false
        }
    }
}
