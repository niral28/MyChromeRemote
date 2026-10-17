@preconcurrency import Network
import AppKit
import CryptoKit
import Foundation
import TVRemoteProtocol

@MainActor
final class RemoteServer: ObservableObject {
    @Published private(set) var isRunning = false
    @Published private(set) var pairingCode = RemoteServer.newCode()
    @Published private(set) var statusText = "Waiting for iPhone and Chrome"

    private var listener: NWListener?
    private var sessions: [UUID: WebSocketSession] = [:]
    private var issuedTokens = Set<String>()
    private var playerStatus = PlayerStatus()
    private var browseState = BrowseState()
    private var expiryTimer: Timer?
    let inputController = InputController()

    @Published private(set) var logLines: [String] = []

    func log(_ message: String) {
        let line = "\(Self.timestamp()) \(message)"
        print(line)
        logLines.append(line)
        if logLines.count > 300 { logLines.removeFirst(logLines.count - 300) }
    }

    func clearLogs() { logLines.removeAll() }

    private static func timestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: Date())
    }

    init() {
        start()
        expiryTimer = Timer.scheduledTimer(withTimeInterval: 600, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.rotatePairingCode() }
        }
    }

    func rotatePairingCode() {
        pairingCode = Self.newCode()
        statusText = "New pairing code is ready"
    }

    private func start() {
        do {
            let listener = try NWListener(using: .tcp, on: 8765)
            listener.service = .init(name: Host.current().localizedName ?? "Mac", type: "_tvremote._tcp")
            listener.newConnectionHandler = { [weak self] connection in
                Task { @MainActor in self?.accept(connection) }
            }
            listener.stateUpdateHandler = { [weak self] state in
                Task { @MainActor in
                    self?.isRunning = state == .ready
                    if case let .failed(error) = state { self?.statusText = "Server error: \(error)" }
                }
            }
            listener.start(queue: .main)
            self.listener = listener
        } catch {
            statusText = "Could not start local server: \(error.localizedDescription)"
        }
    }

    /// A device waiting for the user to approve pairing in the Mac window.
    @Published private(set) var pendingPairDeviceName: String?
    private var pendingPairSessionID: UUID?

    func approvePendingPair() {
        guard let id = pendingPairSessionID, let session = sessions[id],
              let name = pendingPairDeviceName else { return }
        pendingPairSessionID = nil
        pendingPairDeviceName = nil
        completePairing(session: session, deviceName: name)
    }

    func denyPendingPair() {
        guard let id = pendingPairSessionID else { return }
        pendingPairSessionID = nil
        pendingPairDeviceName = nil
        sessionError(id, "Pairing was denied on the Mac")
        log("TV Remote: pairing denied")
    }

    private func completePairing(session: WebSocketSession, deviceName: String) {
        let token = UUID().uuidString
        // Pairing must not hard-fail if the Keychain write is rejected
        // (e.g. items created by a differently-signed build). The token
        // stays valid in memory for this run regardless.
        do {
            try KeychainTokenStore.save(token, for: deviceName)
        } catch {
            log("TV Remote: Keychain save failed for \(deviceName) (\(error)); token valid until this app restarts")
        }
        issuedTokens.insert(token)
        session.isAuthenticated = true
        session.isBrowser = deviceName.hasPrefix("TV Remote Chrome")
        session.send(.paired(token: token))
        log("TV Remote: paired \(deviceName)")
        statusText = "\(deviceName) paired"
    }

    private func accept(_ connection: NWConnection) {
        log("TV Remote: accepted a local connection")
        let id = UUID()
        let session = WebSocketSession(connection: connection) { [weak self] payload in
            Task { @MainActor in self?.receive(payload, from: id) }
        } onClose: { [weak self] in
            Task { @MainActor in self?.sessions.removeValue(forKey: id) }
        } logger: { [weak self] message in
            Task { @MainActor in self?.log(message) }
        }
        let endpointDescription = String(describing: connection.endpoint)
        session.isLoopback = endpointDescription.contains("127.0.0.1") || endpointDescription.contains("::1")
        sessions[id] = session
        session.start()
    }

    private func receive(_ data: Data, from id: UUID) {
        guard let message = try? ProtocolCodec.decoder.decode(ClientMessage.self, from: data),
              let session = sessions[id] else {
            log("TV Remote: rejected invalid protocol message: \(String(decoding: data, as: UTF8.self))")
            sessionError(id, "Invalid message")
            return
        }
        switch message {
        case let .pair(code, deviceName):
            // Legacy code-based pairing, kept for older clients.
            guard code == pairingCode else {
                log("TV Remote: rejected pairing from \(deviceName) with an incorrect code")
                sessionError(id, "Incorrect pairing code")
                return
            }
            completePairing(session: session, deviceName: deviceName)
        case let .pairRequest(deviceName):
            if session.isLoopback {
                // The Chrome extension connects from this same Mac: trust it.
                log("TV Remote: auto-pairing local client \(deviceName)")
                completePairing(session: session, deviceName: deviceName)
            } else {
                pendingPairSessionID = id
                pendingPairDeviceName = deviceName
                statusText = "\(deviceName) wants to pair"
                log("TV Remote: pairing requested by \(deviceName) — approve it in the TV Remote window")
            }
        case let .authenticate(token):
            guard issuedTokens.contains(token) || KeychainTokenStore.contains(token) else {
                if session.isLoopback {
                    // Local Chrome bridge with a stale token: re-issue one.
                    log("TV Remote: re-issuing token for local Chrome bridge")
                    completePairing(session: session, deviceName: "TV Remote Chrome")
                } else {
                    log("TV Remote: rejected unknown device token")
                    sessionError(id, "Unknown device")
                }
                return
            }
            session.isAuthenticated = true
            session.send(.authenticated)
            session.send(.status(playerStatus))
            log("TV Remote: authenticated a paired device")
        case let .command(command):
            guard session.isAuthenticated else { sessionError(id, "Pair this device first"); return }
            // Site shortcuts are handled by the Mac directly: this works even
            // when Chrome has suspended the extension's service worker.
            if let urlString = Self.siteURLs[command], let url = URL(string: urlString),
               let chromeURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.google.Chrome") {
                NSWorkspace.shared.open([url],
                                        withApplicationAt: chromeURL,
                                        configuration: NSWorkspace.OpenConfiguration())
                log("TV Remote: opened \(urlString) in Chrome")
                session.send(.commandAccepted)
                return
            }
            guard let browser = sessions.values.first(where: { $0.isAuthenticated && $0.isBrowser }) else {
                sessionError(id, "No Chrome streaming tab is connected")
                return
            }
            browser.sendRaw(["type": "execute", "command": command.rawValue])
            session.send(.commandAccepted)
        case let .search(query):
            routeBrowser(["type": "search", "query": query], from: id)
        case let .selectTile(tileID):
            routeBrowser(["type": "selectTile", "tileID": tileID], from: id)
        case let .input(event):
            guard session.isAuthenticated else { sessionError(id, "Pair this device first"); return }
            guard !session.isBrowser else { sessionError(id, "Touchpad input is only accepted from the iPhone app"); return }
            do {
                try inputController.perform(event)
            } catch {
                sessionError(id, error.localizedDescription)
            }
        case .status:
            guard session.isAuthenticated else { sessionError(id, "Pair this device first"); return }
            session.send(.status(playerStatus))
        case let .playerStatus(status):
            guard session.isAuthenticated else { sessionError(id, "Pair this device first"); return }
            session.isBrowser = true
            playerStatus = status
            log("TV Remote: player status from \(status.service ?? "browser"), available: \(status.isAvailable)")
            sessions.values.filter(\.isAuthenticated).forEach { $0.send(.status(status)) }
        case let .browseState(state):
            guard session.isAuthenticated else { sessionError(id, "Pair this device first"); return }
            session.isBrowser = true
            browseState = state
            sessions.values.filter(\.isAuthenticated).forEach { $0.send(.browseState(state)) }
        }
    }

    private func routeBrowser(_ message: [String: String], from id: UUID) {
        guard sessions[id]?.isAuthenticated == true,
              let browser = sessions.values.first(where: { $0.isAuthenticated && $0.isBrowser }) else {
            sessionError(id, "No Chrome streaming tab is connected"); return
        }
        browser.sendRaw(message)
        sessions[id]?.send(.commandAccepted)
    }

    private func sessionError(_ id: UUID, _ message: String) {
        sessions[id]?.send(.error(message: message))
    }

    private static let siteURLs: [RemoteCommand: String] = [
        .openDisneyPlus: "https://www.disneyplus.com/home",
        .openHulu: "https://www.hulu.com/",
        .openPeacock: "https://www.peacocktv.com/",
        .openAppleTV: "https://tv.apple.com/",
        .openYouTube: "https://www.youtube.com/"
    ]

    private static func newCode() -> String {
        String(format: "%06d", Int.random(in: 0...999_999))
    }
}

private final class WebSocketSession: @unchecked Sendable {
    let connection: NWConnection
    let onMessage: (Data) -> Void
    let onClose: () -> Void
    let logger: (String) -> Void
    var isAuthenticated = false
    var isBrowser = false
    var isLoopback = false
    private var received = Data()
    private var handshaken = false

    init(connection: NWConnection, onMessage: @escaping (Data) -> Void, onClose: @escaping () -> Void, logger: @escaping (String) -> Void = { print($0) }) {
        self.connection = connection
        self.onMessage = onMessage
        self.onClose = onClose
        self.logger = logger
    }

    func start() {
        connection.start(queue: .main)
        receive()
    }

    func send(_ message: ServerMessage) {
        guard let data = try? ProtocolCodec.encoder.encode(message) else { return }
        sendFrame(data)
    }

    func sendRaw(_ object: [String: String]) {
        guard let data = try? JSONSerialization.data(withJSONObject: object) else { return }
        sendFrame(data)
    }

    private func receive() {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65_536) { [weak self] data, _, complete, error in
            guard let self else { return }
            if let data {
                logger("TV Remote: received \(data.count) bytes")
                self.received.append(data)
                self.processBuffer()
            }
            if complete || error != nil {
                if let error { logger("TV Remote: connection error: \(error)") }
                self.connection.cancel()
                self.onClose()
            } else {
                self.receive()
            }
        }
    }

    private func processBuffer() {
        if !handshaken {
            guard let boundary = received.range(of: Data("\r\n\r\n".utf8)) else { return }
            let request = String(decoding: received[..<boundary.upperBound], as: UTF8.self)
            received.removeSubrange(..<boundary.upperBound)
            let key = request
                .components(separatedBy: "\r\n")
                .compactMap { line -> String? in
                    let fields = line.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
                    guard fields.count == 2,
                          fields[0].trimmingCharacters(in: .whitespacesAndNewlines)
                            .caseInsensitiveCompare("Sec-WebSocket-Key") == .orderedSame else {
                        return nil
                    }
                    return fields[1].trimmingCharacters(in: .whitespacesAndNewlines)
                }
                .first
            guard let key else {
                logger("TV Remote: rejected request headers: \(request.replacingOccurrences(of: "\r\n", with: " | "))")
                connection.cancel(); onClose(); return
            }
            let accept = Insecure.SHA1.hash(data: Data("\(key)258EAFA5-E914-47DA-95CA-C5AB0DC85B11".utf8))
                .withUnsafeBytes { Data($0).base64EncodedString() }
            let response = "HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Accept: \(accept)\r\n\r\n"
            connection.send(content: Data(response.utf8), completion: .contentProcessed { error in
                if let error { self.logger("TV Remote: handshake response failed: \(error)") }
                else { self.logger("TV Remote: WebSocket handshake complete") }
            })
            handshaken = true
        }
        while let payload = nextFrame() { onMessage(payload) }
    }

    private func nextFrame() -> Data? {
        guard received.count >= 2 else { return nil }
        let bytes = [UInt8](received)
        let opcode = bytes[0] & 0x0F
        guard opcode == 0x1 || opcode == 0x2 else {
            connection.cancel()
            return nil
        }
        let masked = bytes[1] & 0x80 != 0
        var length = Int(bytes[1] & 0x7F)
        var index = 2
        if length == 126 {
            guard bytes.count >= 4 else { return nil }
            length = Int(bytes[2]) << 8 | Int(bytes[3]); index = 4
        }
        guard masked, bytes.count >= index + 4 + length else { return nil }
        let mask = Array(bytes[index..<(index + 4)])
        index += 4
        let decoded = Data((0..<length).map { bytes[index + $0] ^ mask[$0 % 4] })
        received.removeSubrange(..<(index + length))
        return decoded
    }

    private func sendFrame(_ payload: Data) {
        guard handshaken, payload.count < 126 else { return }
        var frame = Data([0x81, UInt8(payload.count)])
        frame.append(payload)
        connection.send(content: frame, completion: .contentProcessed { _ in })
    }
}
