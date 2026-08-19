import Foundation

final class AppleMusicController: MusicPlayerControlling {
    let application = MusicApplication.appleMusic

    private let executor: AppleScriptExecuting
    private let locator: MusicApplicationLocating
    private var cachedArtwork: Data?
    private var artworkTrackIdentifier: String?

    init(executor: AppleScriptExecuting, locator: MusicApplicationLocating) {
        self.executor = executor
        self.locator = locator
    }

    func fetchNowPlayingInfo() -> MusicPlaybackSnapshot? {
        guard locator.isRunning(application) else { return nil }
        guard let output = executor.execute(metadataScript) else { return nil }
        guard var snapshot = Self.parse(output: output) else { return nil }

        if artworkTrackIdentifier != snapshot.identifier {
            cachedArtwork = executor.executeRaw(artworkScript)
            artworkTrackIdentifier = snapshot.identifier
        }

        snapshot = MusicPlaybackSnapshot(
            app: snapshot.app,
            title: snapshot.title,
            artist: snapshot.artist,
            album: snapshot.album,
            isPlaying: snapshot.isPlaying,
            currentPosition: snapshot.currentPosition,
            duration: snapshot.duration,
            sourceIdentifier: snapshot.sourceIdentifier,
            artworkURL: nil,
            artworkData: cachedArtwork
        )
        return snapshot
    }

    static func parse(output: String) -> MusicPlaybackSnapshot? {
        guard output != "NOT_PLAYING" else { return nil }
        let parts = output.components(separatedBy: MusicScriptValue.separator)
        guard parts.count == 7 else { return nil }
        let duration = MusicScriptValue.decimal(from: parts[3]) ?? 0
        let currentPosition = MusicScriptValue.decimal(from: parts[4]) ?? 0

        return MusicPlaybackSnapshot(
            app: .appleMusic,
            title: parts[0],
            artist: parts[1],
            album: parts[2],
            isPlaying: parts[5].trimmingCharacters(in: .whitespacesAndNewlines)
                == "true",
            currentPosition: currentPosition,
            duration: duration,
            sourceIdentifier: parts[6],
            artworkURL: nil,
            artworkData: nil
        )
    }

    func skip(by seconds: Int64) {
        guard locator.isRunning(application) else { return }
        let script = """
            tell application "Music"
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
            tell application "Music"
                launch
                \(command)
            end tell
            """
        _ = executor.execute(script)
    }

    func togglePlayPause() {
        guard locator.isRunning(application) else { return }
        let script = """
            tell application "Music"
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
            tell application "Music"
                launch
                set player position to \(value)
            end tell
            """
        _ = executor.execute(script)
    }

    private var metadataScript: String {
        let separator = MusicScriptValue.separator
        return """
            tell application "Music"
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
                        set databaseIdentifier to database ID of current track
                    on error
                        set databaseIdentifier to trackName & artistName & albumName
                    end try
                    return trackName & "\(separator)" & artistName & "\(separator)" & albumName & "\(separator)" & durationValue & "\(separator)" & positionValue & "\(separator)" & playingValue & "\(separator)" & databaseIdentifier
                on error
                    return "NOT_PLAYING"
                end try
            end tell
            """
    }

    private var artworkScript: String {
        """
        tell application "Music"
            launch
            try
                return raw data of artwork 1 of current track
            on error
                return ""
            end try
        end tell
        """
    }
}
