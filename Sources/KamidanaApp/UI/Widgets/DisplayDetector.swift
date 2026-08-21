import AppKit
import CoreGraphics

enum DisplayDetector {
    static func isBuiltInMainDisplay() -> Bool {
        guard let screen = NSScreen.screens.first else { return false }
        return isBuiltIn(screen: screen)
    }

    static func isBuiltIn(screen: NSScreen) -> Bool {
        guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")]
                as? NSNumber
        else {
            return false
        }

        let displayID = CGDirectDisplayID(number.uint32Value)
        return CGDisplayIsBuiltin(displayID) == 1
    }
}
