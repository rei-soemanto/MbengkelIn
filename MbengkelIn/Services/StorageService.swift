//
//  StorageService.swift
//  MbengkelIn
//
//  Created by Rei Soemanto on 27/05/26.
//

import Foundation
import Supabase

class StorageService {
    func uploadAvatar(uid: String, data: Data) async throws -> String {
        let path = "\(uid)/profile.jpg"
        
        let fileOptions = FileOptions(contentType: "image/jpeg", upsert: true)
        
        try await supabase.storage
            .from("avatars")
            .upload(path, data: data, options: fileOptions)
        
        let publicURL = try supabase.storage
            .from("avatars")
            .getPublicURL(path: path)
        
        return publicURL.absoluteString
    }
}
