import Foundation

final class SpotifyMusicController: MusicPlayerControlling {
    let application = MusicApplication.spotify

    private let executor: AppleScriptExecuting
    private let locator: MusicApplicationLocating

    init(executor: AppleScriptExecuting, locator: MusicApplicationLocating) {
        self.executor = executor
        self.locator = locator
    }

    func fetchNowPlayingInfo() -> MusicPlaybackSnapshot? {
        guard locator.isRunning(application) else { return nil }
        guard let output = executor.execute(metadataScript) else { return nil }
        return Self.parse(output: output)
    }

    static func parse(output: String) -> MusicPlaybackSnapshot? {
        guard output != "NOT_PLAYING" else { return nil }
        let parts = output.components(separatedBy: MusicScriptValue.separator)
        guard parts.count == 8 else { return nil }
        let durationMilliseconds = MusicScriptValue.decimal(from: parts[3]) ?? 0
        let currentPosition = MusicScriptValue.decimal(from: parts[4]) ?? 0

        return MusicPlaybackSnapshot(
            app: .spotify,
            title: parts[0],
            artist: parts[1],
            album: parts[2],
            isPlaying: parts[5].trimmingCharacters(in: .whitespacesAndNewlines)
                == "true",
            currentPosition: currentPosition,
            duration: durationMilliseconds / 1000.0,
            sourceIdentifier: parts[7],
            artworkURL: URL(string: parts[6]),
            artworkData: nil
        )
    }

    func skip(by seconds: Int64) {
        guard locator.isRunning(application) else { return }
        let script = """
            tell application "Spotify"
                launch
                if player state is playing or player state is paused then
                    set player position to (player position + \(seconds))
                end if
            end tell
            """
        _ = executor.execute(script)
    }

    func changeTrack(direction: MusicPlayingManager.TrackDirection) {
        guard locator.isRunning(application) else { return }
        let command = direction == .next ? "next track" : "previous track"
        let script = """
            tell application "Spotify"
                launch
                \(command)
            end tell
            """
        _ = executor.execute(script)
    }

    func togglePlayPause() {
        guard locator.isRunning(application) else { return }
        let script = """
            tell application "Spotify"
                launch
                playpause
            end tell
            """
        _ = executor.execute(script)
    }

    func seek(to seconds: Double) {
        guard locator.isRunning(application), seconds.isFinite else { return }
        let value = MusicScriptValue.appleScriptNumber(max(0, seconds))
        let script = """
            tell application "Spotify"
                launch
                set player position to \(value)
            end tell
            """
        _ = executor.execute(script)
    }

    private var metadataScript: String {
        let separator = MusicScriptValue.separator
        return """
            tell application "Spotify"
                launch
                try
                    set currentState to player state
                    if currentState is stopped then return "NOT_PLAYING"
                    set trackName to name of current track
                    set artistName to artist of current track
                    set albumName to album of current track
                    set durationValue to duration of current track
                    set positionValue to player position
                    set playingValue to (currentState is playing)
                    try
                        set artworkValue to artwork url of current track
                    on error
                        set artworkValue to ""
                    end try
                    try
                        set trackIdentifier to id of current track
                    on error
                        set trackIdentifier to trackName & artistName & albumName
                    end try
                    return trackName & "\(separator)" & artistName & "\(separator)" & albumName & "\(separator)" & durationValue & "\(separator)" & positionValue & "\(separator)" & playingValue & "\(separator)" & artworkValue & "\(separator)" & trackIdentifier
                on error
                    return "NOT_PLAYING"
                end try
            end tell
            """
    }
}
