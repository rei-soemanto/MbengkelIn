//
//  NotificationService.swift
//  MbengkelIn
//
//  Created by Bryan on 28/05/26.
//

import Foundation
import UserNotifications

// Local (on-device) notifications. Requires no APNs / Apple Developer setup and
// works on the simulator. Fires while the app is running and watching for orders.
class NotificationService {
    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound, .badge]
        ) { _, _ in }
    }

    func notifyNewOrder(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil // deliver immediately
        )
        UNUserNotificationCenter.current().add(request)

        // Mirror every notification the phone shows onto the paired Apple Watch.
        Task { @MainActor in
            WatchSessionManager.shared.forwardNotification(title: title, body: body)
        }
    }
}
