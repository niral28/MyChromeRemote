import AppKit
import SwiftUI

@main
struct TVRemoteMacApp: App {
    @StateObject private var server = RemoteServer()

    var body: some Scene {
        // A real window as the primary UI: on crowded/notched menu bars
        // macOS can hide status items, so the pair code must live here too.
        WindowGroup("TV Remote") {
            CompanionView(server: server, inputController: server.inputController)
                .frame(minWidth: 340, minHeight: 260)
        }
        .windowResizability(.contentSize)

        MenuBarExtra("TV Remote", systemImage: server.isRunning ? "tv.inset.filled" : "tv") {
            CompanionView(server: server, inputController: server.inputController)
        }
    }
}

struct CompanionView: View {
    @ObservedObject var server: RemoteServer
    @ObservedObject var inputController: InputController
    @State private var showLogs = false

    private func restartApp() {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: configuration) { _, _ in
            DispatchQueue.main.async { NSApp.terminate(nil) }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(server.isRunning ? "TV Remote is ready" : "Starting TV Remote…")
                .font(.headline)
            if let pending = server.pendingPairDeviceName {
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(pending) wants to pair").font(.headline)
                    HStack {
                        Button("Allow") { server.approvePendingPair() }
                            .buttonStyle(.borderedProminent)
                        Button("Deny") { server.denyPendingPair() }
                    }
                }
                .padding(8)
                .background(.yellow.opacity(0.25), in: RoundedRectangle(cornerRadius: 10))
            }
            Text(server.statusText)
                .foregroundStyle(.secondary)
            Text(inputController.isAccessibilityTrusted
                 ? "Touchpad: Accessibility granted. Keep Chrome frontmost."
                 : "Touchpad: Accessibility permission needed.")
                .foregroundStyle(.secondary)
            if !inputController.isAccessibilityTrusted {
                HStack {
                    Button("Grant Accessibility Permission…") {
                        inputController.requestAccessibilityPrompt()
                    }
                    Button("Re-check") { inputController.refreshTrust() }
                }
                Text("Or enable TV Remote in System Settings > Privacy & Security > Accessibility, then restart this app.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Divider()
            HStack {
                Button("View Debug Logs") { showLogs = true }
                Button("Restart TV Remote") { restartApp() }
                Button("Quit TV Remote") { NSApplication.shared.terminate(nil) }
            }
        }
        .padding()
        .onAppear { inputController.refreshTrust() }
        .sheet(isPresented: $showLogs) {
            LogView(server: server)
        }
    }
}

struct LogView: View {
    @ObservedObject var server: RemoteServer
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Debug Logs").font(.headline)
                Spacer()
                Button("Copy") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(server.logLines.joined(separator: "\n"), forType: .string)
                }
                Button("Clear") { server.clearLogs() }
                Button("Done") { dismiss() }
            }
            if server.logLines.isEmpty {
                Text("No log entries yet. Pair a device or send a command from your phone.")
                    .foregroundStyle(.secondary)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        Text(server.logLines.joined(separator: "\n"))
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .id("logEnd")
                    }
                    .onChange(of: server.logLines.count) {
                        proxy.scrollTo("logEnd", anchor: .bottom)
                    }
                }
            }
        }
        .padding()
        .frame(minWidth: 560, minHeight: 380)
    }
}
