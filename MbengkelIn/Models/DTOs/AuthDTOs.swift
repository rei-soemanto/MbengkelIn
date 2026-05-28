//
//  AuthDTOs.swift
//  MbengkelIn
//
//  Created by Rei Soemanto on 27/05/26.
//

import Foundation

// Used by AuthService for sign-up metadata
struct SignUpRequest {
    let email: String
    let password: String
    let name: String
    let phoneNumber: String
}

// Used by UserRepository to update the "users" table
struct ProfileUpdatePayload: Encodable {
    let name: String
    let phone_number: String
}

// Used by UserRepository to update profile image URL
struct ProfileImageUpdatePayload: Encodable {
    let profile_image_url: String
}
