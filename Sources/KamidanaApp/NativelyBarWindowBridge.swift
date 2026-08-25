import AppKit
import CoreGraphics
import Darwin

/// The bridge is optional so the app still starts when a future macOS release
/// removes or changes one of these private symbols.

final class NativelyBarWindowBridge {
    static let shared = NativelyBarWindowBridge()

    private typealias MainConnectionID = @convention(c) () -> Int32
    private typealias SetWindowLevel = @convention(c) (Int32, UInt32, Int32) -> Int32
    private typealias SetWindowTags =
        @convention(c) (
            Int32, UInt32, UnsafeMutablePointer<UInt64>, Int32
        ) -> Int32
    private typealias OrderWindow = @convention(c) (Int32, UInt32, Int32, UInt32) -> Int32

    private let library: UnsafeMutableRawPointer?
    private let connectionID: Int32?
    private let setWindowLevel: SetWindowLevel?
    private let setWindowTags: SetWindowTags?
    private let orderWindow: OrderWindow?

    private init() {
        let path = "/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight"
        let library = dlopen(path, RTLD_LAZY | RTLD_LOCAL)
        self.library = library

        guard let library else {
            connectionID = nil
            setWindowLevel = nil
            setWindowTags = nil
            orderWindow = nil
            return
        }

        let mainConnectionID: MainConnectionID? = Self.resolve(
            "SLSMainConnectionID", from: library
        )
        connectionID = mainConnectionID?()
        setWindowLevel = Self.resolve("SLSSetWindowLevel", from: library)
        setWindowTags = Self.resolve("SLSSetWindowTags", from: library)
        orderWindow = Self.resolve("SLSOrderWindow", from: library)
    }

    deinit {
        if let library {
            dlclose(library)
        }
    }

    func configure(window: NSWindow) {
        guard let connectionID,
            let setWindowLevel,
            let setWindowTags,
            let orderWindow,
            window.windowNumber > 0
        else {
            return
        }

        let windowID = UInt32(window.windowNumber)
        let level = Int32(CGWindowLevelForKey(.backstopMenu))
        _ = setWindowLevel(connectionID, windowID, level)

        var tags = (UInt64(1) << 1) | (UInt64(1) << 16)
        _ = setWindowTags(connectionID, windowID, &tags, 64)
        _ = orderWindow(connectionID, windowID, 1, 0)
    }

    private static func resolve<T>(_ name: String, from library: UnsafeMutableRawPointer) -> T? {
        guard let symbol = dlsym(library, name) else { return nil }
        return unsafeBitCast(symbol, to: T.self)
    }
}

final class StatusBarWindow: NSWindow {
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        // AppKit's visibleFrame, which excludes the menu-bar/notch region.
        frameRect
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
