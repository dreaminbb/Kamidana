import Darwin
import XCTest

@testable import Kamidana

final class MusicProcessDetectionTests: XCTestCase {
    func testProcessDetectionFindsCurrentTestProcess() throws {
        var nameBuffer = [CChar](repeating: 0, count: 1024)
        let nameLength = proc_name(getpid(), &nameBuffer, UInt32(nameBuffer.count))
        let executableName = try XCTUnwrap(
            nameLength > 0 ? String(cString: nameBuffer) : nil
        )

        XCTAssertTrue(
            MusicPlayingManager.isProcessRunning(executableName: executableName)
        )
    }

    func testProcessDetectionRejectsUnknownExecutable() {
        XCTAssertFalse(
            MusicPlayingManager.isProcessRunning(
                executableName: "KamidanaMissingProcessForDetectionTest"
            )
        )
    }
}
