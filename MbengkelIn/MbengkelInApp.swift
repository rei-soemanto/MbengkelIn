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
  supabaseKey: "sb_publishable_1SEf55NC7aq6FRlGxnBjbQ_vtJRWFav",
  options: SupabaseClientOptions(
    auth: SupabaseClientOptions.AuthOptions(
      emitLocalSessionAsInitialSession: true
    )
  )
)

import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        MainActor.assumeIsolated { WatchSessionManager.shared.activate() }
        return true
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
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
