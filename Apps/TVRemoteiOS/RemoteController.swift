import Foundation
import TVRemoteProtocol
import UIKit

@MainActor
final class RemoteController: NSObject, ObservableObject {
    @Published var discoveredMacs: [NetService] = []
    @Published var selectedMac: NetService?
    @Published var pairingCode = ""
    @Published var connectionState = "Looking for your Mac…"
    @Published var playerStatus = PlayerStatus()
    @Published var browseState = BrowseState()

    private let browser = NetServiceBrowser()
    private var socket: URLSessionWebSocketTask?
    private var token: String? { TokenStore.token }

    override init() {
        super.init()
        browser.delegate = self
    }

    func startDiscovery() {
        browser.searchForServices(ofType: "_tvremote._tcp.", inDomain: "local.")
    }

    func connect(to service: NetService) {
        selectedMac = service
        service.delegate = self
        service.resolve(withTimeout: 8)
        connectionState = "Connecting to \(service.name)…"
    }

    @Published var isPaired = false

    func pair() {
        send(.pairRequest(deviceName: UIDevice.current.name))
        connectionState = "Waiting for approval on your Mac…"
    }

    func send(_ command: RemoteCommand) {
        send(.command(command))
    }

    func search(_ query: String) {
        send(.search(query))
    }

    func selectTile(_ id: String) {
        send(.selectTile(id))
    }

    // MARK: - Touchpad (coalesced so a drag does not flood the socket)

    private var pendingMoveX = 0.0
    private var pendingMoveY = 0.0
    private var moveFlushScheduled = false
    private var pendingScrollY = 0.0
    private var scrollFlushScheduled = false

    func touchpadMove(deltaX: Double, deltaY: Double) {
        pendingMoveX += deltaX
        pendingMoveY += deltaY
        guard !moveFlushScheduled else { return }
        moveFlushScheduled = true
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 16_000_000)
            guard let self, self.pendingMoveX != 0 || self.pendingMoveY != 0 else {
                self?.moveFlushScheduled = false
                return
            }
            self.send(.input(.move(deltaX: self.pendingMoveX, deltaY: self.pendingMoveY)))
            self.pendingMoveX = 0
            self.pendingMoveY = 0
            self.moveFlushScheduled = false
        }
    }

    func touchpadScroll(deltaY: Double) {
        pendingScrollY += deltaY
        guard !scrollFlushScheduled else { return }
        scrollFlushScheduled = true
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 16_000_000)
            guard let self, self.pendingScrollY != 0 else {
                self?.scrollFlushScheduled = false
                return
            }
            self.send(.input(.scroll(deltaX: 0, deltaY: self.pendingScrollY)))
            self.pendingScrollY = 0
            self.scrollFlushScheduled = false
        }
    }

    func touchpadClick() { send(.input(.click)) }
    func touchpadMouseDown() { send(.input(.mouseDown)) }
    func touchpadMouseUp() { send(.input(.mouseUp)) }
    func touchpadBack() { send(.input(.back)) }
    func touchpadEnter() { send(.input(.enter)) }
    func typeText(_ text: String) { send(.input(.typeText(text))) }

    private func openSocket() {
        guard let host = selectedMac?.hostName?.trimmingCharacters(in: CharacterSet(charactersIn: ".")),
              let url = URL(string: "ws://\(host):8765") else {
            connectionState = "Could not resolve your Mac"
            return
        }
        socket = URLSession.shared.webSocketTask(with: url)
        socket?.resume()
        connectionState = "Connected"
        if let token { send(.authenticate(token: token)) }
        receive()
    }

    private func send(_ message: ClientMessage) {
        guard let data = try? ProtocolCodec.encoder.encode(message) else { return }
        socket?.send(.data(data)) { [weak self] error in
            if let error { Task { @MainActor in self?.connectionState = error.localizedDescription } }
        }
    }

    private func receive() {
        socket?.receive { [weak self] result in
            Task { @MainActor in
                guard let self else { return }
                switch result {
                case let .success(.data(data)):
                    self.handle(data)
                    self.receive()
                case let .success(.string(string)):
                    self.handle(Data(string.utf8))
                    self.receive()
                case let .failure(error):
                    self.connectionState = "Disconnected: \(error.localizedDescription)"
                @unknown default:
                    self.connectionState = "Unsupported response"
                }
            }
        }
    }

    private func handle(_ data: Data) {
        guard let message = try? ProtocolCodec.decoder.decode(ServerMessage.self, from: data) else { return }
        switch message {
        case let .paired(token):
            TokenStore.save(token)
            isPaired = true
            connectionState = "Paired"
        case .authenticated:
            isPaired = true
            connectionState = "Connected"
        case let .status(status):
            playerStatus = status
        case let .error(message):
            connectionState = message
        case .commandAccepted:
            connectionState = "Command sent"
        case let .browseState(state):
            browseState = state
        }
    }
}

extension RemoteController: NetServiceBrowserDelegate, NetServiceDelegate {
    nonisolated func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        Task { @MainActor in
            guard !self.discoveredMacs.contains(where: { $0.name == service.name }) else { return }
            self.discoveredMacs.append(service)
        }
    }

    nonisolated func netServiceDidResolveAddress(_ sender: NetService) {
        Task { @MainActor in self.openSocket() }
    }

    nonisolated func netService(_ sender: NetService, didNotResolve errorDict: [String: NSNumber]) {
        Task { @MainActor in self.connectionState = "Could not find \(sender.name)" }
    }
}
