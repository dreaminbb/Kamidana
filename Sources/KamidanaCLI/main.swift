import ArgumentParser
import AppKit

@main
struct KamidanaCLI: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "kamidana",
        abstract: "A utility for controlling Kamidana.",
        subcommands: [Display.self]
    )
}

struct Display: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Manage and query displays."
    )

    @Argument(help: "Command to execute (e.g., id)")
    var action: String

    func run() throws {
        if action.lowercased() == "id" {
            FetchDisplayIDs()
        } else {
            print("Unknown action '\(action)'. Available actions: id")
        }
    }

    // use name as the display ID
    private func FetchDisplayIDs() -> Result<[String], Error> {
        do {
            var res: [String] = []
            let screens = NSScreen.screens
            if screens.isEmpty {
                print("No displays found.")
                return .failure(NSError(domain: "", code: 0, userInfo: nil))
            }

            for (index, screen) in screens.enumerated() {
                let isMain = screen == NSScreen.main ? "(Main)" : ""
                let name = screen.localizedName

                if let screenNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID {
                    res.append(name)
                }
            }

            print(res)
            return .success(res)
        } catch {
            print("Error fetching display IDs: \(error)")
            return .failure(error)
        }
    }

}
