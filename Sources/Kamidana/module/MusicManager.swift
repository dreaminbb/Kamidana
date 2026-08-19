import AppKit
import Combine
import Darwin
import Foundation

class MusicPlayingManager: ObservableObject {

    enum PrimaryApp {
        case appleMusic
        case spotify
    }

    // Variables for real-time UI updates
    @Published var title: String = ""
    @Published var artist: String = ""
    @Published var album: String = ""
    @Published var artwork: NSImage? = nil
    @Published var isPlaying: Bool = false
    @Published var primaryApp: PrimaryApp = .spotify
    @Published var currentPosition: Double = 0
    @Published var trackTime: Double = 0

    // Timer for periodic fetching
    private var timer: AnyCancellable?

    init() {
        startMonitoring()
    }

    private func startMonitoring() {
        print("[MusicManager] Start music monitoring (AppleScript)")

        timer = Timer.publish(every: 2.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.fetchNowPlaying()
            }

        // Dispatch asynchronously to prevent SwiftUI crash from synchronously updating @Published during view initialization
        DispatchQueue.main.async { [weak self] in
            self?.fetchNowPlaying()
        }
    }

    private func currentPrimaryAppStr() -> String {
        var key: String
        switch primaryApp {
        case .spotify:
            key = "Spotify"
        case .appleMusic:
            key = "Music"
        }
        return key

    }

    private func isApplicationRunning(_ app: PrimaryApp) -> Bool {
        switch app {
        case .spotify:
            return Self.isProcessRunning(executableName: "Spotify")
        case .appleMusic:
            return Self.isProcessRunning(executableName: "Music")
        }
    }

    static func isProcessRunning(executableName: String) -> Bool {
        var processListSize = proc_listpids(UInt32(PROC_ALL_PIDS), 0, nil, 0)
        guard processListSize > 0 else { return false }

        let capacity = Int(processListSize) / MemoryLayout<pid_t>.size
        var processIdentifiers = [pid_t](repeating: 0, count: capacity)
        processListSize = proc_listpids(
            UInt32(PROC_ALL_PIDS),
            0,
            &processIdentifiers,
            processListSize
        )
        guard processListSize > 0 else { return false }

        let processCount = Int(processListSize) / MemoryLayout<pid_t>.size
        for processIdentifier in processIdentifiers.prefix(processCount) where processIdentifier > 0 {
            var nameBuffer = [CChar](repeating: 0, count: 1024)
            let nameLength = proc_name(
                processIdentifier,
                &nameBuffer,
                UInt32(nameBuffer.count)
            )
            if nameLength > 0, String(cString: nameBuffer) == executableName {
                return true
            }
        }

        return false
    }

    // MARK: - Main Fetch Process

    private func fetchNowPlaying() {

        switch primaryApp {
        case .spotify:
            if fetchFromSpotify() { return }
            if fetchFromMusicApp() {
                primaryApp = .appleMusic
                return
            }
        case .appleMusic:
            if fetchFromMusicApp() { return }
            if fetchFromSpotify() {
                primaryApp = .spotify
                return
            }

        }
        // Clear info if neither app is playing
        clearInfo()
    }

    // MARK: - Fetch from Spotify

    /// Fetch playback information from Spotify. Returns true on success.
    private func fetchFromSpotify() -> Bool {
        guard isApplicationRunning(.spotify) else { return false }

        let checkScript = """
            tell application "Spotify"
                if player state is playing or player state is paused then
                    set trackName to name of current track
                    set trackArtist to artist of current track
                    set trackAlbum to album of current track
                    set artURL to artwork url of current track
                    set pState to player state as string
                    set currentPosition to player position
                    set trackTime to duration of current track
                    return trackName & "\n" & trackArtist & "\n" & trackAlbum & "\n" & artURL & "\n" & pState & "\n" & currentPosition & "\n" & trackTime
                else
                    return "NOT_PLAYING"
                end if
            end tell
            """

        guard let result = runAppleScript(checkScript) else { return false }
        if result == "NOT_RUNNING" || result == "NOT_PLAYING" { return false }

        let parts = result.components(separatedBy: "\n")
        guard parts.count >= 7 else { return false }

        let previousTitle = title

        title = parts[0]
        artist = parts[1]
        album = parts[2]
        isPlaying = (parts[4] == "playing")
        currentPosition = Double(parts[5]) ?? 0.0
        // Spotify duration is in milliseconds, convert to seconds
        trackTime = (Double(parts[6]) ?? 0.0) / 1000.0

        // print(
        //     "[Spotify] title: \(title) | artist: \(artist) | album: \(album) | playing: \(isPlaying)"
        // )

        // Download artwork image from URL (in background)
        let artworkURLString = parts[3]
        // Fetch only when the song changes to avoid unnecessary network traffic
        if previousTitle != title {
            loadArtwork(from: artworkURLString)

            print("Song changed fetch img...")
        }

        return true
    }

    // MARK: - Fetch from Music.app

    /// Fetch playback information from Music.app. Returns true on success.
    private func fetchFromMusicApp() -> Bool {
        guard isApplicationRunning(.appleMusic) else { return false }

        let checkScript = """
            tell application "Music"
                if player state is playing or player state is paused then
                    set trackName to name of current track
                    set trackArtist to artist of current track
                    set trackAlbum to album of current track
                    set pState to player state as string
                    set currentPosition to player position
                    set trackTime to duration of current track
                    return trackName & "\n" & trackArtist & "\n" & trackAlbum & "\n" & pState & "\n" & currentPosition & "\n" & trackTime
                else
                    return "NOT_PLAYING"
                end if
            end tell
            """

        guard let result = runAppleScript(checkScript) else { return false }
        if result == "NOT_RUNNING" || result == "NOT_PLAYING" { return false }

        let parts = result.components(separatedBy: "\n")
        guard parts.count >= 6 else { return false }

        title = parts[0]
        artist = parts[1]
        album = parts[2]
        isPlaying = (parts[3] == "playing")
        currentPosition = Double(parts[4]) ?? 0.0
        trackTime = Double(parts[5]) ?? 0.0

        // print(
        //     "[Music] title: \(title) | artist: \(artist) | album: \(album) | playing: \(isPlaying)"
        // )

        // Music.app artwork is fetched directly as raw data via AppleScript
        loadMusicAppArtwork()

        return true
    }

    // MARK: - Fetch Artwork

    /// Spotify: Download image from URL
    private func loadArtwork(from urlString: String) {
        guard let url = URL(string: urlString) else {
            artwork = nil
            return
        }
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            DispatchQueue.main.async {
                if let data = data {
                    self?.artwork = NSImage(data: data)
                } else {
                    self?.artwork = nil
                }
            }
        }.resume()
    }

    /// Music.app: Fetch raw image data directly using AppleScript
    private func loadMusicAppArtwork() {
        guard isApplicationRunning(.appleMusic) else {
            artwork = nil
            return
        }

        let script = """
            tell application "Music"
                try
                    set artData to raw data of artwork 1 of current track
                    return artData
                on error
                    return ""
                end try
            end tell
            """

        // Extract data from AppleScript execution result
        let appleScript = NSAppleScript(source: script)
        var errorInfo: NSDictionary?
        let result = appleScript?.executeAndReturnError(&errorInfo)

        if let result = result {
            artwork = NSImage(data: result.data)
        } else {
            artwork = nil
        }
    }

    // MARK: - Utilities

    /// Execute AppleScript and return the result as a string
    private func runAppleScript(_ source: String) -> String? {
        let appleScript = NSAppleScript(source: source)
        var errorInfo: NSDictionary?
        let result = appleScript?.executeAndReturnError(&errorInfo)

        if let error = errorInfo {
            if error[NSAppleScript.errorNumber] as? Int == -600 {
                return nil
            }
            print("[AppleScript] Error: \(error)")
            return nil
        }

        return result?.stringValue
    }

    /// Clear playback information
    private func clearInfo() {
        if !title.isEmpty || isPlaying {
            title = ""
            artist = ""
            album = ""
            artwork = nil
            isPlaying = false
        }
    }

    public func skipSong(sec: Int64) {
        guard isApplicationRunning(primaryApp) else { return }
        let key = currentPrimaryAppStr()

        let script = """
                    tell application "\(key)"
                        if player state is playing then
                            set player position to (player position + \(sec))
                            return "SUCCESS"
                        end if
                    end tell
                    return "NOT_PLAYING"
            """

        if let result = runAppleScript(script), result == "SUCCESS" {
            print("\(key): Succeed to skip song \(sec)s skipping")
            return
        }

    }

    enum TrackDirection {
        case next
        case previous
    }

    /// A description
    /// - Parameter direction:direction Bool -> true:Next false:Previous
    public func changeTrack(direction: TrackDirection) {
        guard isApplicationRunning(primaryApp) else { return }

        let key: String

        switch direction {
        case .next:
            key = "next"
        case .previous:
            key = "previous"
        }

        let appName = currentPrimaryAppStr()
        let changeTrackScript = """
                        tell application "\(appName)"
                            if player state is playing then
                                \(key) track
                                return "SUCCESS"
                            end if
                        end tell
                        return "NOT_PLAYING"
            """

        if let result = runAppleScript(changeTrackScript), result == "SUCCESS" {
            return
        }

    }

    public func pauseMusic() {
        guard isApplicationRunning(primaryApp) else { return }
        let appName = currentPrimaryAppStr()
        // The playpause command is supported by both Spotify and Music.
        // This toggles between play and pause.
        let pauseScript = """
                        tell application "\(appName)"
                            playpause
                            return "SUCCESS"
                        end tell
            """

        if let result = runAppleScript(pauseScript), result == "SUCCESS" {
            // State can be updated manually for immediate UI reflection,
            // or handled by the next timer cycle (every 2 seconds).
            return
        }
    }
    
    // MARK: - Seek (Change playback position)
    public func seek(to seconds: Double) {
        guard isApplicationRunning(primaryApp) else { return }
        let appName = currentPrimaryAppStr()
        let script = """
            tell application "\(appName)"
                set player position to \(seconds)
                return "SUCCESS"
            end tell
        """
        if runAppleScript(script) == "SUCCESS" {
            self.currentPosition = seconds
        }
    }
}
