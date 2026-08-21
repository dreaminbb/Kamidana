import AppKit
import Combine
import Foundation

final class MusicPlayingManager: ObservableObject {
    enum PrimaryApp: Hashable {
        case appleMusic
        case spotify
    }

    enum TrackDirection {
        case next
        case previous
    }

    @Published var title: String = ""
    @Published var artist: String = ""
    @Published var album: String = ""
    @Published var artwork: NSImage?
    @Published var isPlaying: Bool = false
    @Published var primaryApp: PrimaryApp = .spotify
    @Published var currentPosition: Double = 0
    @Published var trackTime: Double = 0

    private let controllers: [PrimaryApp: MusicPlayerControlling]
    private let fetchQueue = DispatchQueue(
        label: "com.shin.Kamidana.music-fetch",
        qos: .utility
    )
    private var timer: AnyCancellable?
    private var isFetchInProgress = false
    private var currentTrackIdentifier: String?

    init(
        executor: AppleScriptExecuting = OsaScriptExecutor(),
        locator: MusicApplicationLocating = SystemMusicApplicationLocator(),
        startsMonitoring: Bool = true
    ) {
        let spotifyController = SpotifyMusicController(
            executor: executor,
            locator: locator
        )
        let appleMusicController = AppleMusicController(
            executor: executor,
            locator: locator
        )
        controllers = [
            .spotify: spotifyController,
            .appleMusic: appleMusicController,
        ]

        if startsMonitoring {
            startMonitoring()
        }
    }

    deinit {
        timer?.cancel()
    }

    private func startMonitoring() {
        timer = Timer.publish(every: 2.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.fetchNowPlaying()
            }

        DispatchQueue.main.async { [weak self] in
            self?.fetchNowPlaying()
        }
    }

    private func fetchNowPlaying() {
        guard !isFetchInProgress else { return }
        isFetchInProgress = true

        let preferredApp = primaryApp
        fetchQueue.async { [weak self] in
            guard let self else { return }

            let appOrder: [PrimaryApp] = preferredApp == .spotify
                ? [.spotify, .appleMusic]
                : [.appleMusic, .spotify]
            let result = appOrder.lazy.compactMap { app -> MusicPlaybackSnapshot? in
                self.controllers[app]?.fetchNowPlayingInfo()
            }.first

            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.isFetchInProgress = false

                guard let result else {
                    self.clearInfo()
                    return
                }

                self.apply(result)
            }
        }
    }

    private func apply(_ snapshot: MusicPlaybackSnapshot) {
        primaryApp = snapshot.app
        title = snapshot.title
        artist = snapshot.artist
        album = snapshot.album
        isPlaying = snapshot.isPlaying
        currentPosition = snapshot.currentPosition
        trackTime = snapshot.duration

        guard currentTrackIdentifier != snapshot.identifier else { return }
        currentTrackIdentifier = snapshot.identifier

        if let artworkData = snapshot.artworkData {
            artwork = NSImage(data: artworkData)
        } else if let artworkURL = snapshot.artworkURL {
            artwork = nil
            loadArtwork(from: artworkURL, for: snapshot.identifier)
        } else {
            artwork = nil
        }
    }

    private func loadArtwork(from url: URL, for trackIdentifier: String) {
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let data, let image = NSImage(data: data) else { return }

            DispatchQueue.main.async {
                guard self?.currentTrackIdentifier == trackIdentifier else { return }
                self?.artwork = image
            }
        }.resume()
    }

    private func clearInfo() {
        guard
            !title.isEmpty || !artist.isEmpty || !album.isEmpty || artwork != nil
                || isPlaying || currentPosition != 0 || trackTime != 0
        else {
            return
        }

        title = ""
        artist = ""
        album = ""
        artwork = nil
        isPlaying = false
        currentPosition = 0
        trackTime = 0
        currentTrackIdentifier = nil
    }

    private func controllerForPrimaryApp() -> MusicPlayerControlling? {
        controllers[primaryApp]
    }

    public func skipSong(sec: Int64) {
        guard let controller = controllerForPrimaryApp() else { return }
        fetchQueue.async {
            controller.skip(by: sec)
        }
    }

    public func changeTrack(direction: TrackDirection) {
        guard let controller = controllerForPrimaryApp() else { return }
        fetchQueue.async { [weak self] in
            controller.changeTrack(direction: direction)
            self?.scheduleRefresh()
        }
    }

    public func pauseMusic() {
        guard let controller = controllerForPrimaryApp() else { return }
        fetchQueue.async { [weak self] in
            controller.togglePlayPause()
            self?.scheduleRefresh()
        }
    }

    public func seek(to seconds: Double) {
        guard let controller = controllerForPrimaryApp() else { return }
        currentPosition = seconds
        fetchQueue.async {
            controller.seek(to: seconds)
        }
    }

    private func scheduleRefresh() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.fetchNowPlaying()
        }
    }

    static func isProcessRunning(executableName: String) -> Bool {
        SystemMusicApplicationLocator.isProcessRunning(
            executableName: executableName
        )
    }
}
