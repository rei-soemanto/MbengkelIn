//
//  WatchSessionManager+Location.swift
//  MbengkelIn
//
//  Created by Rei Soemanto on 03/06/26.
//

import Foundation
import Supabase

// Realtime subscription on the assigned bengkel's live location so the watch's
// "finish only when in range" gate updates live (mirrors subscribeBidChannel).
@MainActor
extension WatchSessionManager {
    func subscribeLocationChannel(requestId: String) async {
        if locationChannelRequestId == requestId, locationChannel != nil { return }
        if let locationChannel { await supabase.removeChannel(locationChannel) }
        let channel = supabase.channel("watch-locations-\(requestId)")
        locationChannel = channel
        locationChannelRequestId = requestId
        let stream = channel.postgresChange(
            AnyAction.self, schema: "public", table: "order_locations",
            filter: "service_request_id=eq.\(requestId)"
        )
        Task { [weak self] in
            await channel.subscribe()
            for await _ in stream { await self?.rebuildState() }
        }
    }
}
