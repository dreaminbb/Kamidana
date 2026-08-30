import AppKit
import CoreGraphics

enum DisplayDetector {
    static func isBuiltInMainDisplay() -> Bool {
        guard let screen = NSScreen.screens.first else { return false }
        return isBuiltIn(screen: screen)
    }

    static func displayID(for screen: NSScreen) -> CGDirectDisplayID? {
        guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")]
                as? NSNumber
        else {
            return nil
        }

        return CGDirectDisplayID(number.uint32Value)
    }

    static func isBuiltIn(screen: NSScreen) -> Bool {
        guard let displayID = displayID(for: screen) else {
            return false
        }

        return CGDisplayIsBuiltin(displayID) == 1
    }
}
