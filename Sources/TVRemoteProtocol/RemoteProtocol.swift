import Foundation

public enum RemoteCommand: String, Codable, CaseIterable, Sendable {
    case togglePlayback
    case mute
    case volumeUp
    case volumeDown
    case seekBackward
    case seekForward
    case toggleFullscreen
    case next
    case previous
    case back, home, up, down, left, right, select
    case openSearch, submitSearch
    case openDisneyPlus, openHulu, openPeacock, openAppleTV, openYouTube
}

public struct BrowseTile: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let title: String
    public let artworkURL: String?
}

public struct BrowseState: Codable, Sendable, Equatable {
    public var title: String?
    public var tiles: [BrowseTile]
    public var focusedTileID: String?
    public init(title: String? = nil, tiles: [BrowseTile] = [], focusedTileID: String? = nil) {
        self.title = title; self.tiles = tiles; self.focusedTileID = focusedTileID
    }
}

public enum InputEvent: Codable, Sendable, Equatable {
    case move(deltaX: Double, deltaY: Double)
    case scroll(deltaX: Double, deltaY: Double)
    case click
    case mouseDown
    case mouseUp
    case typeText(String)
    case back
    case enter

    private enum CodingKeys: String, CodingKey { case type, deltaX, deltaY, text }
    private enum EventType: String, Codable { case move, scroll, click, mouseDown, mouseUp, typeText, back, enter }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        switch try c.decode(EventType.self, forKey: .type) {
        case .move: self = .move(deltaX: try c.decode(Double.self, forKey: .deltaX), deltaY: try c.decode(Double.self, forKey: .deltaY))
        case .scroll: self = .scroll(deltaX: try c.decode(Double.self, forKey: .deltaX), deltaY: try c.decode(Double.self, forKey: .deltaY))
        case .click: self = .click
        case .mouseDown: self = .mouseDown
        case .mouseUp: self = .mouseUp
        case .typeText: self = .typeText(try c.decode(String.self, forKey: .text))
        case .back: self = .back
        case .enter: self = .enter
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .move(dx, dy): try c.encode(EventType.move, forKey: .type); try c.encode(dx, forKey: .deltaX); try c.encode(dy, forKey: .deltaY)
        case let .scroll(dx, dy): try c.encode(EventType.scroll, forKey: .type); try c.encode(dx, forKey: .deltaX); try c.encode(dy, forKey: .deltaY)
        case .click: try c.encode(EventType.click, forKey: .type)
        case .mouseDown: try c.encode(EventType.mouseDown, forKey: .type)
        case .mouseUp: try c.encode(EventType.mouseUp, forKey: .type)
        case let .typeText(text): try c.encode(EventType.typeText, forKey: .type); try c.encode(text, forKey: .text)
        case .back: try c.encode(EventType.back, forKey: .type)
        case .enter: try c.encode(EventType.enter, forKey: .type)
        }
    }
}

public enum ClientMessage: Codable, Sendable {
    case pair(code: String, deviceName: String)
    case authenticate(token: String)
    case command(RemoteCommand)
    case status
    case playerStatus(PlayerStatus)
    case search(String)
    case selectTile(String)
    case browseState(BrowseState)
    case input(InputEvent)
    case pairRequest(deviceName: String)

    private enum CodingKeys: String, CodingKey { case type, code, deviceName, token, command, status, query, tileID, browse, input }
    private enum MessageType: String, Codable { case pair, authenticate, command, status, playerStatus, search, selectTile, browseState, input, pairRequest }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(MessageType.self, forKey: .type) {
        case .pair:
            self = .pair(code: try container.decode(String.self, forKey: .code),
                         deviceName: try container.decode(String.self, forKey: .deviceName))
        case .authenticate:
            self = .authenticate(token: try container.decode(String.self, forKey: .token))
        case .command:
            self = .command(try container.decode(RemoteCommand.self, forKey: .command))
        case .status:
            self = .status
        case .playerStatus:
            self = .playerStatus(try container.decode(PlayerStatus.self, forKey: .status))
        case .search: self = .search(try container.decode(String.self, forKey: .query))
        case .selectTile: self = .selectTile(try container.decode(String.self, forKey: .tileID))
        case .browseState: self = .browseState(try container.decode(BrowseState.self, forKey: .browse))
        case .input: self = .input(try container.decode(InputEvent.self, forKey: .input))
        case .pairRequest: self = .pairRequest(deviceName: try container.decode(String.self, forKey: .deviceName))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .pair(code, deviceName):
            try container.encode(MessageType.pair, forKey: .type)
            try container.encode(code, forKey: .code)
            try container.encode(deviceName, forKey: .deviceName)
        case let .authenticate(token):
            try container.encode(MessageType.authenticate, forKey: .type)
            try container.encode(token, forKey: .token)
        case let .command(command):
            try container.encode(MessageType.command, forKey: .type)
            try container.encode(command, forKey: .command)
        case .status:
            try container.encode(MessageType.status, forKey: .type)
        case let .playerStatus(status):
            try container.encode(MessageType.playerStatus, forKey: .type)
            try container.encode(status, forKey: .status)
        case let .search(query):
            try container.encode(MessageType.search, forKey: .type); try container.encode(query, forKey: .query)
        case let .selectTile(id):
            try container.encode(MessageType.selectTile, forKey: .type); try container.encode(id, forKey: .tileID)
        case let .browseState(state):
            try container.encode(MessageType.browseState, forKey: .type); try container.encode(state, forKey: .browse)
        case let .input(event):
            try container.encode(MessageType.input, forKey: .type); try container.encode(event, forKey: .input)
        case let .pairRequest(deviceName):
            try container.encode(MessageType.pairRequest, forKey: .type); try container.encode(deviceName, forKey: .deviceName)
        }
    }
}

public struct PlayerStatus: Codable, Sendable, Equatable {
    public var service: String?
    public var title: String?
    public var isAvailable: Bool

    public init(service: String? = nil, title: String? = nil, isAvailable: Bool = false) {
        self.service = service
        self.title = title
        self.isAvailable = isAvailable
    }
}

public enum ServerMessage: Codable, Sendable {
    case paired(token: String)
    case authenticated
    case status(PlayerStatus)
    case error(message: String)
    case commandAccepted
    case browseState(BrowseState)

    private enum CodingKeys: String, CodingKey { case type, token, status, message, browse }
    private enum MessageType: String, Codable { case paired, authenticated, status, error, commandAccepted, browseState }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(MessageType.self, forKey: .type) {
        case .paired:
            self = .paired(token: try container.decode(String.self, forKey: .token))
        case .authenticated:
            self = .authenticated
        case .status:
            self = .status(try container.decode(PlayerStatus.self, forKey: .status))
        case .error:
            self = .error(message: try container.decode(String.self, forKey: .message))
        case .commandAccepted:
            self = .commandAccepted
        case .browseState: self = .browseState(try container.decode(BrowseState.self, forKey: .browse))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .paired(token):
            try container.encode(MessageType.paired, forKey: .type)
            try container.encode(token, forKey: .token)
        case .authenticated:
            try container.encode(MessageType.authenticated, forKey: .type)
        case let .status(status):
            try container.encode(MessageType.status, forKey: .type)
            try container.encode(status, forKey: .status)
        case let .error(message):
            try container.encode(MessageType.error, forKey: .type)
            try container.encode(message, forKey: .message)
        case .commandAccepted:
            try container.encode(MessageType.commandAccepted, forKey: .type)
        case let .browseState(state):
            try container.encode(MessageType.browseState, forKey: .type)
            try container.encode(state, forKey: .browse)
        }
    }
}

public enum ProtocolCodec {
    public static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }()

    public static let decoder = JSONDecoder()
}
