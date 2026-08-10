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
        // C言語のBooleanは0以外がtrueとなるため、!= 0 で判定するのが確実
        return CGDisplayIsBuiltin(displayID) != 0
    }
}
