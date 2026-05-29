//
//  MbengkelInWatchOSApp.swift
//  MbengkelInWatchOS Watch App
//
//  Created by Rei Soemanto on 22/05/26.
//

import SwiftUI

@main
struct MbengkelInWatchOS_Watch_AppApp: App {
    @WKApplicationDelegateAdaptor(WatchAppDelegate.self) private var delegate
    @StateObject private var client = WatchConnectivityClient.shared

    var body: some Scene {
        WindowGroup {
            ContentView().environmentObject(client)
        }
    }
}

final class WatchAppDelegate: NSObject, WKApplicationDelegate {
    func applicationDidFinishLaunching() {
        // Activate WatchConnectivity at launch so transferred notifications and
        // state updates are handled even when the UI isn't foregrounded.
        MainActor.assumeIsolated { WatchConnectivityClient.shared.activate() }
    }
}
