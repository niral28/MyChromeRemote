import SwiftUI
import TVRemoteProtocol

struct RemoteView: View {
    @EnvironmentObject private var remote: RemoteController

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    connectionCard
                    if remote.selectedMac != nil && remote.connectionState != "Paired" {
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
        HStack {
            TextField("6-digit code", text: $remote.pairingCode)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
            Button("Pair") { remote.pair() }
                .buttonStyle(.borderedProminent)
                .disabled(remote.pairingCode.count != 6)
        }
    }

    private var nowPlaying: some View {
        VStack(spacing: 5) {
            Text(remote.playerStatus.service ?? "No supported tab")
                .font(.headline)
            Text(remote.playerStatus.title ?? "Open Hulu or Disney+ in Chrome")
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var controls: some View {
        VStack(spacing: 18) {
            HStack(spacing: 24) {
                command(.previous, icon: "backward.end.fill")
                command(.seekBackward, icon: "gobackward.15")
                command(.togglePlayback, icon: "playpause.fill", prominent: true)
                command(.seekForward, icon: "goforward.15")
                command(.next, icon: "forward.end.fill")
            }
            HStack(spacing: 24) {
                command(.volumeDown, icon: "speaker.minus.fill")
                command(.mute, icon: "speaker.slash.fill")
                command(.volumeUp, icon: "speaker.plus.fill")
                command(.toggleFullscreen, icon: "arrow.up.left.and.arrow.down.right")
            }
        }
    }

    private func command(_ command: RemoteCommand, icon: String, prominent: Bool = false) -> some View {
        Button { remote.send(command) } label: {
            Image(systemName: icon)
                .font(prominent ? .largeTitle : .title2)
                .frame(width: prominent ? 76 : 54, height: prominent ? 76 : 54)
        }
        .buttonStyle(.borderedProminent)
        .tint(prominent ? .red : .accentColor)
        .accessibilityLabel(command.rawValue)
    }
}
