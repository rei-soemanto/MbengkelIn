//
//  PaymentPlaceholderView.swift
//  BengkelIn
//
//  Created by Rei Soemanto on 23/04/26.
//


import SwiftUI

// Bryan's Scope
struct PaymentPlaceholderView: View {
    var body: some View {
        VStack {
            Image(systemName: "creditcard")
                .font(.system(size: 50))
                .foregroundColor(.blue)
            Text("Payment Management")
                .font(.title2)
                .fontWeight(.semibold)
                .padding(.top)
            Text("Top-up and balance history will be built by Bryan.")
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding()
        }
        .navigationTitle("Payment")
    }
}

// Bryan's Scope
struct HistoryPlaceholderView: View {
    var body: some View {
        NavigationStack {
            VStack {
                Image(systemName: "clock")
                    .font(.system(size: 50))
                    .foregroundColor(.blue)
                Text("Order History")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .padding(.top)
                Text("List of past services will be built by Bryan.")
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding()
            }
            .navigationTitle("History")
        }
    }
}

// Your Future Scope
struct ProfilePlaceholderView: View {
    @ObservedObject var viewModel: AuthViewModel
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Name: \(viewModel.currentUser?.name ?? "")")
                    Text("Email: \(viewModel.currentUser?.email ?? "")")
                    Text("Role: \(viewModel.currentUser?.role ?? "")")
                }
                
                Section {
                    Button("Sign Out") {
                        viewModel.signOut()
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("Profile")
        }
    }
}

struct AddVehiclePlaceholder: View {
    var body: some View { Text("Add Vehicle Form goes here").navigationTitle("Add Vehicle") }
}

struct UpdateProfilePlaceholder: View {
    var body: some View { Text("Update Profile Form goes here").navigationTitle("Edit Profile") }
}

struct RegisterBengkelPlaceholder: View {
    var body: some View { Text("Bengkel Registration Form goes here").navigationTitle("Register Bengkel") }
}
