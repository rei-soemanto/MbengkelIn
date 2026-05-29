//
//  ChatPresence.swift
//  MbengkelIn
//
//  Created by Bryan Fernando Dinata on 29/05/26.
//

import Foundation

// Tracks which order's chat screen is currently open. Background chat watchers
// (ChatWatchViewModel) read this to suppress notifications and unread counts for
// the conversation the user is already reading.
@MainActor
final class ChatPresence {
    static let shared = ChatPresence()
    private init() {}

    var activeServiceRequestId: String?
}
