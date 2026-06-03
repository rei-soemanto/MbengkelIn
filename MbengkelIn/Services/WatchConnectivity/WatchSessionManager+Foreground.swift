//
//  WatchSessionManager+Foreground.swift
//  MbengkelIn
//
//  Created by Rei Soemanto on 03/06/26.
//

import Foundation
import Supabase

// Re-establishes realtime channels (which die while the phone is backgrounded)
// and pushes the fresh truth to the watch when the phone returns to foreground.
@MainActor
extension WatchSessionManager {

    func refreshOnForeground() async {
        guard customerId != nil else { return }
        if let requestChannel { await supabase.removeChannel(requestChannel) }
        if let bidChannel { await supabase.removeChannel(bidChannel) }
        if let locationChannel { await supabase.removeChannel(locationChannel) }
        requestChannel = nil
        bidChannel = nil; bidChannelRequestId = nil
        locationChannel = nil; locationChannelRequestId = nil
        await subscribeRequestChannel()
        await rebuildState()
    }
}
