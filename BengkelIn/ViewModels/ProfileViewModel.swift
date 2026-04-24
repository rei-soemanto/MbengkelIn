//
//  ProfileViewModel.swift
//  BengkelIn
//
//  Created by Rei Soemanto on 24/04/26.
//

import SwiftUI
import Combine
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage

@MainActor
class ProfileViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    
    func updateProfile(name: String, phoneNumber: String) async -> Bool {
        isLoading = true
        errorMessage = nil
        successMessage = nil
        guard let uid = Auth.auth().currentUser?.uid else { return false }
        
        do {
            try await Firestore.firestore().collection("users").document(uid).updateData([
                "name": name,
                "phoneNumber": phoneNumber
            ])
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
        
        guard let uid = Auth.auth().currentUser?.uid else { return false }
        
        let storageRef = Storage.storage().reference().child("profile_images/\(uid).jpg")
        
        do {
            let _ = try await storageRef.putDataAsync(imageData, metadata: nil)
            
            let downloadURL = try await storageRef.downloadURL()
            
            let uniqueURLString = downloadURL.absoluteString + "&v=\(Date().timeIntervalSince1970)"
            
            try await Firestore.firestore().collection("users").document(uid).updateData([
                "profileImageUrl": uniqueURLString
            ])
            
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
