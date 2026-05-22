//
//  ContentView.swift
//  MbengkelIn
//
//  Created by Rei Soemanto on 23/04/26.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var authViewModel = AuthViewModel()
    
    var body: some View {
        Group {
            if authViewModel.userSession != nil {
                TabView {
                    DashboardView(authViewModel: authViewModel)
                        .tabItem {
                            Label("Dashboard", systemImage: "house.fill")
                        }
                    
                    PaymentPlaceholderView()
                        .tabItem {
                            Label("Payment", systemImage: "creditcard.fill")
                        }
                    
                    HistoryPlaceholderView()
                        .tabItem {
                            Label("History", systemImage: "clock.fill")
                        }
                    
                    ProfileView(authViewModel: authViewModel)
                        .tabItem {
                            Label("Profile", systemImage: "person.fill")
                        }
                }
            } else {
                LoginView(authViewModel: authViewModel)
            }
        }
        .tint(.primary)
    }
}

#Preview {
    ContentView()
}
