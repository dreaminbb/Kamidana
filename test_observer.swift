import AppKit

class Observer {
    init() {
        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: nil) { _ in
            guard let screen = NSScreen.screens.first,
                  let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
                print("Could not get screen")
                return
            }
            let displayID = CGDirectDisplayID(number.uint32Value)
            let isBuiltIn = CGDisplayIsBuiltin(displayID) != 0
            print("Screen parameters changed. Main screen is built-in: \(isBuiltIn)")
        }
    }
}
let obs = Observer()
print("Listening... (Press Ctrl+C to stop)")
RunLoop.main.run(until: Date(timeIntervalSinceNow: 2))
