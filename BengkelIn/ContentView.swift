//
//  ContentView.swift
//  BengkelIn
//
//  Created by Rei Soemanto on 23/04/26.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = AuthViewModel()
    
    var body: some View {
        Group {
            if viewModel.userSession != nil {
                TabView {
                    DashboardView(viewModel: viewModel)
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
                    
                    ProfilePlaceholderView(viewModel: viewModel)
                        .tabItem {
                            Label("Profile", systemImage: "person.fill")
                        }
                }
            } else {
                LoginView(viewModel: viewModel)
            }
        }
        .tint(.black)
    }
}

#Preview("Light Theme") {
    ContentView()
    .preferredColorScheme(.light)
}

#Preview("Dark Theme") {
    ContentView()
    .preferredColorScheme(.dark)
}
