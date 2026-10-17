import SwiftUI
import TVRemoteProtocol

struct RemoteView: View {
    @EnvironmentObject private var remote: RemoteController
    @State private var lastTouchLocation: CGPoint?
    @State private var touchMoved = false
    @State private var dragMode = false
    @State private var isMouseHeld = false
    @State private var lastScrollLocation: CGPoint?
    @State private var showKeyboard = false
    @State private var typedText = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Image("MyChromeRemote")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 120)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                        .background(Color.black, in: RoundedRectangle(cornerRadius: 16))
                        .accessibilityHidden(true)
                    connectionCard
                    if remote.selectedMac != nil && !remote.isPaired {
                        pairingCard
                    }
                    nowPlaying
                    controls
                }
                .padding()
            }
            .navigationTitle("TV Remote")
        }
    }

    private var connectionCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(remote.connectionState, systemImage: "wifi")
                .fixedSize(horizontal: false, vertical: true)
            if remote.discoveredMacs.isEmpty {
                Text("Make sure TV Remote is open on your Mac and both devices use the same Wi-Fi.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(remote.discoveredMacs, id: \.name) { mac in
                    Button(mac.name) { remote.connect(to: mac) }
                        .buttonStyle(.bordered)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var pairingCard: some View {
        VStack(spacing: 8) {
            Button {
                remote.pair()
            } label: {
                Label("Request Pairing", systemImage: "link")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            Text("Then click Allow in the TV Remote window on your Mac.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    /// Best available "what's on" label: the playing video's title first,
    /// then the current page title, then the service name.
    private var nowPlayingTitle: String {
        if remote.playerStatus.isAvailable,
           let title = remote.playerStatus.title, !title.isEmpty {
            return title
        }
        if let title = remote.browseState.title, !title.isEmpty {
            return title
        }
        if let title = remote.playerStatus.title, !title.isEmpty {
            return title
        }
        return remote.playerStatus.service ?? "Open a streaming site in Chrome"
    }

    private var nowPlaying: some View {
        VStack(spacing: 5) {
            Text(nowPlayingTitle)
                .font(.headline)
                .multilineTextAlignment(.center)
                .lineLimit(3)
            if let service = remote.playerStatus.service {
                Text(service)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var touchpad: some View {
        VStack(spacing: 10) {
            HStack {
                Text("Touchpad").font(.headline)
                Spacer()
                Text("Drag").font(.caption).foregroundStyle(.secondary)
                Toggle("Drag", isOn: $dragMode).labelsHidden()
            }
            HStack(spacing: 10) {
                Button { remote.touchpadBack() } label: {
                    Label("Back", systemImage: "chevron.backward")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                Button { showKeyboard = true } label: {
                    Label("Type", systemImage: "keyboard")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16).fill(.thinMaterial)
                    VStack(spacing: 6) {
                        Image(systemName: "hand.draw").font(.largeTitle).foregroundStyle(.secondary)
                        Text(dragMode ? "Drag to move with mouse held" : "Drag to move - tap to click")
                            .font(.caption).foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                        Text("Keep Chrome frontmost on the Mac").font(.caption2).foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                    }
                    .padding(.horizontal, 8)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 210)
                .contentShape(RoundedRectangle(cornerRadius: 16))
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            if let last = lastTouchLocation {
                                let dx = Double(value.location.x - last.x) * 1.6
                                let dy = Double(value.location.y - last.y) * 1.6
                                if abs(value.translation.width) + abs(value.translation.height) > 8 { touchMoved = true }
                                if dragMode && !isMouseHeld {
                                    isMouseHeld = true
                                    remote.touchpadMouseDown()
                                }
                                remote.touchpadMove(deltaX: dx, deltaY: dy)
                            }
                            lastTouchLocation = value.location
                        }
                        .onEnded { _ in
                            if isMouseHeld {
                                isMouseHeld = false
                                remote.touchpadMouseUp()
                            } else if !touchMoved {
                                remote.touchpadClick()
                            }
                            lastTouchLocation = nil
                            touchMoved = false
                        }
                )

                // Dedicated scroll strip (SwiftUI DragGesture reports one finger).
                ZStack {
                    RoundedRectangle(cornerRadius: 12).fill(.thinMaterial)
                    Image(systemName: "arrow.up.and.down").foregroundStyle(.secondary)
                }
                .frame(width: 40, height: 210)
                .contentShape(RoundedRectangle(cornerRadius: 12))
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            if let last = lastScrollLocation {
                                remote.touchpadScroll(deltaY: Double(value.location.y - last.y) * 2)
                            }
                            lastScrollLocation = value.location
                        }
                        .onEnded { _ in lastScrollLocation = nil }
                )
                .accessibilityLabel("Scroll")
            }
        }
        .sheet(isPresented: $showKeyboard) {
            NavigationStack {
                VStack(spacing: 16) {
                    TextField("Type to send to Chrome", text: $typedText, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(3...6)
                    Button("Send Text") {
                        remote.typeText(typedText)
                        typedText = ""
                        showKeyboard = false
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(typedText.isEmpty)
                    Button("Send Text + Enter") {
                        remote.typeText(typedText)
                        remote.touchpadEnter()
                        typedText = ""
                        showKeyboard = false
                    }
                    .buttonStyle(.bordered)
                    .disabled(typedText.isEmpty)
                    Spacer()
                }
                .padding()
                .navigationTitle("Type on Mac")
            }
        }
    }

    private var controls: some View {
        VStack(spacing: 18) {
            touchpad
            HStack(spacing: 8) {
                siteButton("Disney+", .openDisneyPlus, color: Color(red: 0.05, green: 0.1, blue: 0.3))
                siteButton("Hulu", .openHulu, color: Color(red: 0.1, green: 0.8, blue: 0.45), darkText: true)
                siteButton("Peacock", .openPeacock, color: .black)
                siteButton("Apple TV", .openAppleTV, color: Color(white: 0.2))
                siteButton("YouTube", .openYouTube, color: Color(red: 0.85, green: 0.1, blue: 0.1))
            }
            HStack {
                command(.back, icon: "chevron.backward")
                command(.openSearch, icon: "magnifyingglass")
            }
            HStack(spacing: 10) {
                command(.previous, icon: "backward.end.fill")
                command(.seekBackward, icon: "gobackward.15")
                command(.togglePlayback, icon: "playpause.fill", prominent: true)
                command(.seekForward, icon: "goforward.15")
                command(.next, icon: "forward.end.fill")
            }
            HStack(spacing: 10) {
                command(.volumeDown, icon: "speaker.minus.fill")
                command(.mute, icon: "speaker.slash.fill")
                command(.volumeUp, icon: "speaker.plus.fill")
                command(.toggleFullscreen, icon: "arrow.up.left.and.arrow.down.right")
            }
            if !remote.browseState.tiles.isEmpty {
                Text(remote.browseState.title ?? "Browse").font(.headline)
                    .lineLimit(2)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(remote.browseState.tiles) { tile in
                        Button { remote.selectTile(tile.id) } label: {
                            VStack(alignment: .leading) {
                                AsyncImage(url: URL(string: tile.artworkURL ?? "")) { image in
                                    image.resizable().scaledToFill()
                                } placeholder: { Color.secondary.opacity(0.2) }
                                .frame(height: 90).clipShape(RoundedRectangle(cornerRadius: 8))
                                Text(tile.title).lineLimit(2).font(.caption)
                            }
                        }
                        .overlay(RoundedRectangle(cornerRadius: 8)
                            .stroke(remote.browseState.focusedTileID == tile.id ? .red : .clear, lineWidth: 3))
                    }
                }
            }
        }
    }

    private func siteButton(_ title: String, _ command: RemoteCommand, color: Color, darkText: Bool = false) -> some View {
        Button { remote.send(command) } label: {
            Text(title)
                .font(.caption.weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.65)
                .foregroundStyle(darkText ? .black : .white)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(color, in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open \(title)")
    }

    private func command(_ command: RemoteCommand, icon: String, prominent: Bool = false) -> some View {
        Button { remote.send(command) } label: {
            Image(systemName: icon)
                .font(prominent ? .title : .body)
                .foregroundStyle(.white)
                .frame(width: prominent ? 62 : 46, height: prominent ? 62 : 46)
                .background(prominent ? Color.red : Color.accentColor,
                            in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(command.rawValue)
    }
}
