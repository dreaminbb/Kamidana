import AppKit
import ArgumentParser
import Foundation
import KamidanaApp

@main
struct KamidanaCLI: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "kamidana",
        abstract: "A utility for controlling Kamidana.",
        subcommands: [Display.self, Explain.self]
    )

    @Option(
        name: .long,
        help:
            "Write true or false to global.launch_at_login in ~/.config/kamidana/config.yaml. A running Kamidana synchronizes the change; otherwise it synchronizes at the next launch."
    )
    var launchAtLogin: String?

    func run() throws {
        guard let launchAtLogin else { return }

        let isEnabled: Bool
        switch launchAtLogin.lowercased() {
        case "true":
            isEnabled = true
        case "false":
            isEnabled = false
        default:
            throw ValidationError("--launch-at-login must be true or false.")
        }

        try ConfigManager(shouldLoadUserConfiguration: false).updateLaunchAtLogin(
            isEnabled: isEnabled)
    }
}

struct Explain: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Print the active Kamidana runtime configuration as JSON."
    )

    func run() {
        let snapshotURL = ConfigManager.resolveRuntimeExplanationFileURL()
        let requestID = UUID().uuidString
        DistributedNotificationCenter.default().post(
            name: .kamidanaRuntimeExplanationRequest,
            object: nil,
            userInfo: ["request_id": requestID]
        )

        let deadline = Date().addingTimeInterval(2)
        var snapshot: KamidanaRuntimeConfiguration?
        while Date() < deadline {
            if let data = try? Data(contentsOf: snapshotURL),
               let candidate = try? JSONDecoder().decode(
                   KamidanaRuntimeConfiguration.self,
                   from: data
               ),
               candidate.requestID == requestID {
                snapshot = candidate
                break
            }
            Thread.sleep(forTimeInterval: 0.05)
        }

        guard let snapshot else {
            printJSON(
                ExplainError(
                    code: "runtime_explanation_timeout",
                    message: "The running Kamidana process did not respond to the explain request.",
                    snapshotPath: snapshotURL.path
                )
            )
            return
        }

        guard let process = NSRunningApplication(
            processIdentifier: pid_t(snapshot.pid)
        ), !process.isTerminated else {
            printJSON(
                ExplainError(
                    code: "kamidana_not_running",
                    message: "The runtime configuration belongs to a process that is no longer running.",
                    snapshotPath: snapshotURL.path
                )
            )
            return
        }

        printJSON(snapshot)
    }

    private func printJSON<T: Encodable>(_ value: T) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(value) else { return }
        FileHandle.standardOutput.write(data)
        FileHandle.standardOutput.write(Data([0x0A]))
    }
}

private struct ExplainError: Encodable {
    let error: String
    let message: String
    let snapshotPath: String

    init(code: String, message: String, snapshotPath: String) {
        self.error = code
        self.message = message
        self.snapshotPath = snapshotPath
    }

    private enum CodingKeys: String, CodingKey {
        case error
        case message
        case snapshotPath = "snapshot_path"
    }
}

struct Display: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Manage and query displays."
    )

    @Argument(help: "Command to execute (e.g., id)")
    var action: String

    func run() {
        if action.lowercased() == "id" {
            fetchDisplayIDs().forEach { print($0) }
        } else {
            print("Unknown action '\(action)'. Available actions: id")
        }
    }

    private func fetchDisplayIDs() -> [String] {
        NSScreen.screens.compactMap { screen in
            guard
                let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")]
                    as? NSNumber
            else {
                return nil
            }
            return "\(screen.localizedName): \(number.uint32Value)"
        }
    }

}
