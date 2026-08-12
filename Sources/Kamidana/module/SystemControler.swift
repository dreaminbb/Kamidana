import AppKit
import Foundation

// アプリの強制終了
// NOTE: fastfetchコマンドを実行するのは超クールかもしれない

// brew or nixのアップデート利用可能なパッケージ
// システムモニター || ビルドインのターミナルでbtopを起動

enum SystemControlError: Error, LocalizedError {
    case scriptFailed(String)

    var errorDescription: String? {
        switch self {
        case .scriptFailed(let msg):
            return msg
        }
    }
}

class SystemController {

    static let shutdownScript = "tell application \"System Events\" to shut down"
    static let rebootScript = "tell application \"System Events\" to restart"
    static let logoutScript = "tell application \"System Events\" to log out"
    static let screenLockScript =
        #"tell application "System Events" to keystroke "q" using {command down, control down}"#
    static let aboutThisMacAppPath = "/System/Library/CoreServices/Applications/About This Mac.app"

    static func runAppleScript(_ script: String) -> Result<Bool, SystemControlError> {

        guard let appleScript = NSAppleScript(source: script) else {
            return .failure(.scriptFailed("Failed to initialize NSAppleScript"))
        }
        var error: NSDictionary?

        appleScript.executeAndReturnError(&error)
        if let error = error {
            let errorMsg = error[NSAppleScript.errorMessage] as? String ?? "Unknown error"
            print("System controlling failed: \(errorMsg)")
            return .failure(.scriptFailed(errorMsg))
        }

        return .success(true)
    }

    func shutdownSystem() -> Result<Bool, SystemControlError> {
        return SystemController.runAppleScript(SystemController.shutdownScript)
    }

    func rebootSystem() -> Result<Bool, SystemControlError> {
        return SystemController.runAppleScript(SystemController.rebootScript)
    }

    func logoutSystem() -> Result<Bool, SystemControlError> {
        return SystemController.runAppleScript(SystemController.logoutScript)
    }
    func lockScreen() -> Result<Bool, SystemControlError> {
        return SystemController.runAppleScript(SystemController.screenLockScript)
    }

    func showAboutThisMac() -> Result<Bool, SystemControlError> {

        let url = URL(fileURLWithPath: SystemController.aboutThisMacAppPath)
        let result = NSWorkspace.shared.open(url)

        if result {
            print("'About this Mac' has been opened")
            return .success(true)
        } else {
            print("failed to open 'About this Mac'")
            return .failure(.scriptFailed("Failed to open 'About this Mac'"))
        }

    }

}
