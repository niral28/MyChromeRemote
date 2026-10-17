//
//  TVRemoteiOSApp.swift
//  TVRemoteiOS
//
//  Created by Niral Shah on 10/2/26.
//

import SwiftUI

@main
struct TVRemoteiOSApp: App {
    @StateObject private var remote = RemoteController()

    var body: some Scene {
        WindowGroup {
            RemoteView()
                .environmentObject(remote)
                .task { remote.startDiscovery() }
        }
    }
}
