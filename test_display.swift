import AppKit
import CoreGraphics

for screen in NSScreen.screens {
    if let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber {
        let displayID = CGDirectDisplayID(number.uint32Value)
        let isBuiltIn = CGDisplayIsBuiltin(displayID)
        print("Screen: \(screen.localizedName), ID: \(displayID), BuiltIn: \(isBuiltIn)")
    }
}
