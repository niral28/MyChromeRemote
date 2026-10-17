import Testing
@testable import TVRemoteProtocol

@Test func commandRoundTrip() throws {
    let original = ClientMessage.command(.seekForward)
    let encoded = try ProtocolCodec.encoder.encode(original)
    let decoded = try ProtocolCodec.decoder.decode(ClientMessage.self, from: encoded)
    guard case let .command(command) = decoded else {
        Issue.record("Decoded an unexpected message")
        return
    }
    #expect(command == .seekForward)
}

@Test func playerStatusRoundTrip() throws {
    let original = ServerMessage.status(.init(service: "Hulu", title: "Example", isAvailable: true))
    let encoded = try ProtocolCodec.encoder.encode(original)
    let decoded = try ProtocolCodec.decoder.decode(ServerMessage.self, from: encoded)
    guard case let .status(status) = decoded else {
        Issue.record("Decoded an unexpected message")
        return
    }
    #expect(status == PlayerStatus(service: "Hulu", title: "Example", isAvailable: true))
}

@Test func inputEventRoundTrip() throws {
    for event in [InputEvent.move(deltaX: 12.5, deltaY: -3), .scroll(deltaX: 0, deltaY: 40), .click, .typeText("Simpsons"), .back, .enter] {
        let encoded = try ProtocolCodec.encoder.encode(ClientMessage.input(event))
        guard case let .input(decoded) = try ProtocolCodec.decoder.decode(ClientMessage.self, from: encoded) else {
            Issue.record("Decoded an unexpected input message")
            return
        }
        #expect(decoded == event)
    }
}

@Test func browseStateRoundTrip() throws {
    let state = BrowseState(title: "Disney+", tiles: [.init(id: "1", title: "Bluey", artworkURL: "https://example.com/bluey.jpg")], focusedTileID: "1")
    let encoded = try ProtocolCodec.encoder.encode(ServerMessage.browseState(state))
    guard case let .browseState(decoded) = try ProtocolCodec.decoder.decode(ServerMessage.self, from: encoded) else {
        Issue.record("Decoded an unexpected browse message")
        return
    }
    #expect(decoded == state)
}
