import AppKit
import CoreGraphics

enum DisplayDetector {
    static func isBuiltInMainDisplay() -> Bool {
        guard
            let screen = NSScreen.screens.first,
            let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")]
                as? NSNumber
        else {
            return false
        }

        let displayID = CGDirectDisplayID(number.uint32Value)
        // In C, non-zero is true for boolean values, so checking != 0 is reliable
        print("displayID: \(displayID != 0) \(displayID)")
        return CGDisplayIsBuiltin(displayID) == 1
    }
}
