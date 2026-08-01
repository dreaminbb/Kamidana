import AppKit
import Combine
import Foundation

class MusicPlayingManager: ObservableObject {

    // UI側でリアルタイムに画面を書き換えるための変数
    @Published var title: String = ""
    @Published var artist: String = ""
    @Published var album: String = ""
    @Published var artwork: NSImage? = nil
    @Published var isPlaying: Bool = false

    // 定期取得用のタイマー
    private var timer: AnyCancellable?

    init() {
        startMonitoring()
    }

    private func startMonitoring() {
        #if DEBUG
            print("🎵 start music monitoring (AppleScript)")
        #endif

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

    // MARK: - メインの取得処理

    private func fetchNowPlaying() {
        // Spotify → Music.app の優先順で、再生中のアプリから情報を取得する
        if fetchFromSpotify() { return }
        if fetchFromMusicApp() { return }

        // どちらも再生していなければ空にする
        clearInfo()
    }

    // MARK: - Spotify からの取得

    /// Spotifyから再生情報を取得する。成功したら true を返す。
    private func fetchFromSpotify() -> Bool {
        // Spotifyが起動しているか & 再生中かを確認するスクリプト
        let checkScript = """
            tell application "System Events"
                if not (exists process "Spotify") then return "NOT_RUNNING"
            end tell
            tell application "Spotify"
                if player state is playing then
                    set trackName to name of current track
                    set trackArtist to artist of current track
                    set trackAlbum to album of current track
                    set artURL to artwork url of current track
                    return trackName & "\n" & trackArtist & "\n" & trackAlbum & "\n" & artURL
                else
                    return "NOT_PLAYING"
                end if
            end tell
            """

        guard let result = runAppleScript(checkScript) else { return false }
        if result == "NOT_RUNNING" || result == "NOT_PLAYING" { return false }

        let parts = result.components(separatedBy: "\n")
        guard parts.count >= 4 else { return false }

        let previousTitle = title

        title = parts[0]
        artist = parts[1]
        album = parts[2]
        isPlaying = true

        #if DEBUG
            print("🎵 [Spotify] title: \(title) | artist: \(artist) | album: \(album)")
        #endif

        // アートワークURLから画像をダウンロード（バックグラウンド）
        let artworkURLString = parts[3]
        // 無駄なトラフィックを防ぐために、曲が変わった際にのみ取得する
        if previousTitle != "" && previousTitle != title {
            loadArtwork(from: artworkURLString)

            #if DEBUG
                print("Song changed fetch img...")
            #endif
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
                if player state is playing then
                    set trackName to name of current track
                    set trackArtist to artist of current track
                    set trackAlbum to album of current track
                    return trackName & "\n" & trackArtist & "\n" & trackAlbum
                else
                    return "NOT_PLAYING"
                end if
            end tell
            """

        guard let result = runAppleScript(checkScript) else { return false }
        if result == "NOT_RUNNING" || result == "NOT_PLAYING" { return false }

        let parts = result.components(separatedBy: "\n")
        guard parts.count >= 3 else { return false }

        title = parts[0]
        artist = parts[1]
        album = parts[2]
        isPlaying = true

        #if DEBUG
            print("🎵 [Music] title: \(title) | artist: \(artist) | album: \(album)")
        #endif

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
            #if DEBUG
                print("⚠️ AppleScript error: \(error)")
            #endif
            return nil
        }

        return result?.stringValue
    }

    /// 再生情報をクリアする
    private func clearInfo() {
        if isPlaying {
            title = ""
            artist = ""
            album = ""
            artwork = nil
            isPlaying = false
        }
    }
}
