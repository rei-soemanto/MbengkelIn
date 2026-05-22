//
//  MbengkelInApp.swift
//  MbengkelIn
//
//  Created by Rei Soemanto on 23/04/26.
//

import SwiftUI
import Foundation
import Supabase

let supabase = SupabaseClient(
  supabaseURL: URL(string: "https://nerrnpbopdfrdcfvjowx.supabase.co")!,
  supabaseKey: "sb_publishable_1SEf55NC7aq6FRlGxnBjbQ_vtJRWFav"
)

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        return true
    }
}

@main
struct MbengkelInApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
