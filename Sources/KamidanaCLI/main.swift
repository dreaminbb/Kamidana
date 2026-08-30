import ArgumentParser
import AppKit
import KamidanaApp

@main
struct KamidanaCLI: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "kamidana",
        abstract: "A utility for controlling Kamidana.",
        subcommands: [Display.self]
    )

    @Option(
        name: .long,
        help: "Write true or false to global.launch_at_login in ~/.config/kamidana/config.yaml. A running Kamidana synchronizes the change; otherwise it synchronizes at the next launch."
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

        try ConfigManager(shouldLoadUserConfiguration: false).updateLaunchAtLogin(isEnabled: isEnabled)
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
            guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")]
                as? NSNumber
            else {
                return nil
            }
            return "\(screen.localizedName): \(number.uint32Value)"
        }
    }

}
