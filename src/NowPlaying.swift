import AppKit

/// "Tocando agora" do Spotify e do app Música.
/// Atualizações chegam por notificações distribuídas que os players já publicam;
/// comandos e capa usam AppleScript (pede permissão de Automação na primeira vez).
final class NowPlaying: ObservableObject {
    enum Player: CaseIterable {
        case spotify, music

        var appName: String { self == .spotify ? "Spotify" : "Music" }
        var displayName: String { self == .spotify ? "Spotify" : "Música" }
        var bundleID: String { self == .spotify ? "com.spotify.client" : "com.apple.Music" }
        var notification: String {
            self == .spotify ? "com.spotify.client.PlaybackStateChanged" : "com.apple.Music.playerInfo"
        }
        var isRunning: Bool {
            !NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).isEmpty
        }
    }

    enum Command {
        case playPause, next, previous

        var script: String {
            switch self {
            case .playPause: "playpause"
            case .next: "next track"
            case .previous: "previous track"
            }
        }
    }

    @Published private(set) var player: Player?
    @Published private(set) var title = ""
    @Published private(set) var artist = ""
    @Published private(set) var isPlaying = false
    @Published private(set) var artwork: NSImage?
    private var artworkKey = ""
    private var observers: [NSObjectProtocol] = []

    var hasTrack: Bool { player != nil && !title.isEmpty }

    init() {
        let center = DistributedNotificationCenter.default()
        for player in Player.allCases {
            observers.append(center.addObserver(
                forName: Notification.Name(player.notification), object: nil, queue: .main
            ) { [weak self] note in
                let info = note.userInfo ?? [:]
                self?.apply(player: player,
                            state: (info["Player State"] as? String ?? "").lowercased(),
                            title: info["Name"] as? String ?? "",
                            artist: info["Artist"] as? String ?? "")
            })
        }
        refresh()
    }

    deinit {
        observers.forEach(DistributedNotificationCenter.default().removeObserver)
    }

    func send(_ command: Command) {
        guard let target = player ?? Player.allCases.first(where: \.isRunning) else { return }
        run("tell application \"\(target.appName)\" to \(command.script)")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in self?.refresh() }
    }

    /// Lê o estado atual dos players abertos (sem abrir nenhum que esteja fechado).
    func refresh() {
        for player in Player.allCases where player.isRunning {
            let script = """
                tell application "\(player.appName)"
                    set s to player state as string
                    if s is "stopped" then return "stopped"
                    return s & linefeed & (name of current track) & linefeed & (artist of current track)
                end tell
                """
            guard let output = run(script)?.stringValue else { continue }
            let parts = output.components(separatedBy: "\n")
            apply(player: player, state: parts[0],
                  title: parts.count > 1 ? parts[1] : "",
                  artist: parts.count > 2 ? parts[2] : "")
        }
    }

    private func apply(player source: Player, state: String, title: String, artist: String) {
        if state == "stopped" || title.isEmpty {
            if player == source { clear() }
            return
        }
        // Um player pausado não rouba o lugar de outro que está tocando
        if let current = player, current != source, isPlaying, state != "playing" { return }

        player = source
        self.title = title
        self.artist = artist
        isPlaying = state == "playing"

        let key = "\(source)|\(title)|\(artist)"
        if key != artworkKey {
            artworkKey = key
            artwork = nil
            loadArtwork(for: source, key: key)
        }
    }

    private func clear() {
        player = nil
        title = ""
        artist = ""
        isPlaying = false
        artwork = nil
        artworkKey = ""
    }

    private func loadArtwork(for player: Player, key: String) {
        switch player {
        case .spotify:
            guard let link = run("tell application \"Spotify\" to artwork url of current track")?.stringValue,
                  let url = URL(string: link) else { return }
            URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
                guard let data, let image = NSImage(data: data) else { return }
                DispatchQueue.main.async {
                    if self?.artworkKey == key { self?.artwork = image }
                }
            }.resume()
        case .music:
            let script = "tell application \"Music\" to get raw data of artwork 1 of current track"
            if let data = run(script)?.data, let image = NSImage(data: data) {
                artwork = image
            }
        }
    }

    @discardableResult
    private func run(_ source: String) -> NSAppleEventDescriptor? {
        var error: NSDictionary?
        let result = NSAppleScript(source: source)?.executeAndReturnError(&error)
        return error == nil ? result : nil
    }
}
