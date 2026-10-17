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
