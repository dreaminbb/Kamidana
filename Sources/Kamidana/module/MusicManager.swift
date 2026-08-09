import AppKit
import Combine
import Foundation

class MusicPlayingManager: ObservableObject {

    enum PrimaryApp {
        case appleMusic
        case spotify
    }

    // UI側でリアルタイムに画面を書き換えるための変数
    @Published var title: String = ""
    @Published var artist: String = ""
    @Published var album: String = ""
    @Published var artwork: NSImage? = nil
    @Published var isPlaying: Bool = false
    @Published var primaryApp: PrimaryApp = .spotify
    @Published var currentPosition: Double = 0
    @Published var trackTime: Double = 0

    // 定期取得用のタイマー
    private var timer: AnyCancellable?

    init() {
        startMonitoring()
    }

    private func startMonitoring() {
        print("🎵 start music monitoring (AppleScript)")

        timer = Timer.publish(every: 2.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.fetchNowPlaying()
            }

        // Viewの初期化中に同期的に@Publishedを更新するとSwiftUIがクラッシュするため非同期化
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

    // MARK: - メインの取得処理

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
        // どちらも再生していなければ空にする
        clearInfo()
    }

    // MARK: - Spotify からの取得

    /// Spotifyから再生情報を取得する。成功したら true を返す。
    private func fetchFromSpotify() -> Bool {
        // Spotifyが起動しているか & 再生中/一時停止中かを確認するスクリプト
        let checkScript = """
            tell application "System Events"
                if not (exists process "Spotify") then return "NOT_RUNNING"
            end tell
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
        // Spotifyのdurationはミリ秒なので秒に変換
        trackTime = (Double(parts[6]) ?? 0.0) / 1000.0

        print(
            "🎵 [Spotify] title: \(title) | artist: \(artist) | album: \(album) | playing: \(isPlaying)"
        )

        // アートワークURLから画像をダウンロード（バックグラウンド）
        let artworkURLString = parts[3]
        // 無駄なトラフィックを防ぐために、曲が変わった際にのみ取得する
        if previousTitle != title {
            loadArtwork(from: artworkURLString)

            print("Song changed fetch img...")
        }

        return true
    }

    // MARK: - Music.app からの取得

    /// Music.appから再生情報を取得する。成功したら true を返す。
    private func fetchFromMusicApp() -> Bool {
        let checkScript = """
            tell application "System Events"
                if not (exists process "Music") then return "NOT_RUNNING"
            end tell
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

        print(
            "🎵 [Music] title: \(title) | artist: \(artist) | album: \(album) | playing: \(isPlaying)"
        )

        // Music.appのアートワークはAppleScriptで直接データとして取得
        loadMusicAppArtwork()

        return true
    }

    // MARK: - アートワーク取得

    /// Spotify: URLから画像をダウンロードする
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

    /// Music.app: AppleScriptで画像データを直接取得する
    private func loadMusicAppArtwork() {
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

        // AppleScriptの実行結果からデータを取り出す
        let appleScript = NSAppleScript(source: script)
        var errorInfo: NSDictionary?
        let result = appleScript?.executeAndReturnError(&errorInfo)

        if let result = result {
            artwork = NSImage(data: result.data)
        } else {
            artwork = nil
        }
    }

    // MARK: - ユーティリティ

    /// AppleScriptを実行し、結果を文字列として返す
    private func runAppleScript(_ source: String) -> String? {
        let appleScript = NSAppleScript(source: source)
        var errorInfo: NSDictionary?
        let result = appleScript?.executeAndReturnError(&errorInfo)

        if let error = errorInfo {
            print("⚠️ AppleScript error: \(error)")
            return nil
        }

        return result?.stringValue
    }

    /// 再生情報をクリアする
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

        var key: String = currentPrimaryAppStr()

        let script = """
                    tell application "System Events"
                        if not (exists process "\(key)") then return "NOT_RUNNING"
                    end tell
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

        let key: String

        switch direction {
        case .next:
            key = "next"
        case .previous:
            key = "previous"
        }

        let appName = currentPrimaryAppStr()
        let changeTrackScript = """
                        tell application "System Events"
                            if not (exists process "\(appName)") then return "NOT_RUNNING"
                        end tell
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
        let appName = currentPrimaryAppStr()
        // SpotifyとMusicの両方で playpause コマンドが使用可能です
        // これにより再生中は一時停止し、一時停止中は再生します
        let pauseScript = """
                        tell application "System Events"
                            if not (exists process "\(appName)") then return "NOT_RUNNING"
                        end tell
                        tell application "\(appName)"
                            playpause
                            return "SUCCESS"
                        end tell
            """

        if let result = runAppleScript(pauseScript), result == "SUCCESS" {
            // UIを即座に反映させるために手動で状態を更新するか、
            // 次回のタイマー処理(2秒ごと)に任せます。
            return
        }
    }
    
    // MARK: - シーク（再生位置の変更）
    public func seek(to seconds: Double) {
        let appName = currentPrimaryAppStr()
        let script = """
            tell application "System Events"
                if not (exists process "\(appName)") then return "NOT_RUNNING"
            end tell
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
