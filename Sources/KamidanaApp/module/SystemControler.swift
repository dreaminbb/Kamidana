import AppKit
import Foundation

// Force quit application
// Available update packages for brew or nix

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

    static let sleepScript = "tell application \"System Events\" to sleep"
    static let aboutThisMacAppPath = "/System/Applications/Utilities/System Information.app"

    static func runAppleScript(_ script: String) {
        DispatchQueue.global(qos: .userInitiated).async {
            guard let appleScript = NSAppleScript(source: script) else {
                print("System controlling failed: Failed to initialize NSAppleScript")
                return
            }
        var error: NSDictionary?

        appleScript.executeAndReturnError(&error)
        if let error = error {
            let errorMsg = error[NSAppleScript.errorMessage] as? String ?? "Unknown error"
            print("System controlling failed: \(errorMsg)")
        } else {
            print("System command completed.")
        }
        }
    }

    func shutdownSystem() {
        SystemController.runAppleScript(SystemController.shutdownScript)
    }

    func rebootSystem() {
        SystemController.runAppleScript(SystemController.rebootScript)
    }

    func sleepSystem() {
        SystemController.runAppleScript(SystemController.sleepScript)
    }

    func logoutSystem() {
        SystemController.runAppleScript(SystemController.logoutScript)
    }
    func lockScreen() {
        SystemController.runAppleScript(SystemController.screenLockScript)
    }

    func showAboutThisMac() {
        let url = URL(fileURLWithPath: SystemController.aboutThisMacAppPath)
        let result = NSWorkspace.shared.open(url)

        if result {
            print("'About this Mac' has been opened")
        } else {
            print("failed to open 'About this Mac'")
        }
    }

}
