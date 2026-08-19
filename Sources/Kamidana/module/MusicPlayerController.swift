import AppKit
import Darwin
import Foundation

struct MusicPlaybackSnapshot: Equatable {
    let app: MusicPlayingManager.PrimaryApp
    let title: String
    let artist: String
    let album: String
    let isPlaying: Bool
    let currentPosition: Double
    let duration: Double
    let sourceIdentifier: String
    let artworkURL: URL?
    let artworkData: Data?

    var identifier: String {
        [String(describing: app), sourceIdentifier].joined(separator: "|")
    }
}

struct MusicApplication {
    let app: MusicPlayingManager.PrimaryApp
    let name: String
    let bundleIdentifier: String
    let executableName: String

    static let spotify = MusicApplication(
        app: .spotify,
        name: "Spotify",
        bundleIdentifier: "com.spotify.client",
        executableName: "Spotify"
    )

    static let appleMusic = MusicApplication(
        app: .appleMusic,
        name: "Music",
        bundleIdentifier: "com.apple.Music",
        executableName: "Music"
    )
}

protocol AppleScriptExecuting {
    func execute(_ source: String) -> String?
    func executeRaw(_ source: String) -> Data?
}

extension AppleScriptExecuting {
    func executeRaw(_ source: String) -> Data? {
        nil
    }
}

final class OsaScriptExecutor: AppleScriptExecuting {
    private let executableURL = URL(fileURLWithPath: "/usr/bin/osascript")

    func execute(_ source: String) -> String? {
        let process = Process()
        let standardOutput = Pipe()

        process.executableURL = executableURL
        process.arguments = ["-e", source]
        process.standardOutput = standardOutput
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return nil
        }

        guard process.terminationStatus == 0 else { return nil }
        let data = standardOutput.fileHandleForReading.readDataToEndOfFile()
        guard var output = String(data: data, encoding: .utf8) else { return nil }

        while output.last?.isNewline == true {
            output.removeLast()
        }
        return output
    }

    func executeRaw(_ source: String) -> Data? {
        if !Thread.isMainThread {
            return DispatchQueue.main.sync {
                executeRaw(source)
            }
        }

        guard let appleScript = NSAppleScript(source: source) else { return nil }
        var errorInfo: NSDictionary?
        let result = appleScript.executeAndReturnError(&errorInfo)
        guard errorInfo == nil else { return nil }
        return result.data
    }
}

protocol MusicApplicationLocating {
    func isRunning(_ application: MusicApplication) -> Bool
}

struct SystemMusicApplicationLocator: MusicApplicationLocating {
    func isRunning(_ application: MusicApplication) -> Bool {
        if !NSRunningApplication.runningApplications(
            withBundleIdentifier: application.bundleIdentifier
        ).isEmpty {
            return true
        }

        return Self.isProcessRunning(executableName: application.executableName)
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
        for processIdentifier in processIdentifiers.prefix(processCount)
        where processIdentifier > 0 {
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
}

protocol MusicPlayerControlling: AnyObject {
    var application: MusicApplication { get }

    func fetchNowPlayingInfo() -> MusicPlaybackSnapshot?
    func skip(by seconds: Int64)
    func changeTrack(direction: MusicPlayingManager.TrackDirection)
    func togglePlayPause()
    func seek(to seconds: Double)
}

enum MusicScriptValue {
    static let separator = "|||SEP|||"

    static func decimal(from value: String) -> Double? {
        Double(value.replacingOccurrences(of: ",", with: "."))
    }

    static func appleScriptNumber(_ value: Double) -> String {
        String(format: "%.3f", locale: Locale(identifier: "en_US_POSIX"), value)
    }
}
