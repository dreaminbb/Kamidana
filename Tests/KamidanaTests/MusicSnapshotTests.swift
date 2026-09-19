import Combine
import XCTest

@testable import KamidanaApp

final class MusicSnapshotTests: XCTestCase {
    func testPausedTrackRetainsMetadataAndMissingTrackClearsIt() {
        let executor = SnapshotExecutor()
        let manager = MusicPlayingManager(
            executor: executor, locator: SnapshotLocator(), startsMonitoring: false
        )
        let loaded = expectation(description: "Paused snapshot published")
        var subscription = manager.$trackTime.dropFirst().sink { duration in
            if duration == 180 { loaded.fulfill() }
        }
        manager.fetchNowPlaying()
        wait(for: [loaded], timeout: 2)
        XCTAssertEqual(manager.title, "Paused track")
        XCTAssertEqual(manager.artist, "Artist")
        XCTAssertFalse(manager.isPlaying)
        XCTAssertEqual(manager.currentPosition, 42)
        subscription.cancel()

        executor.hasTrack = false
        let cleared = expectation(description: "Missing snapshot clears metadata")
        subscription = manager.$trackTime.dropFirst().sink { duration in
            if duration == 0 { cleared.fulfill() }
        }
        manager.fetchNowPlaying()
        wait(for: [cleared], timeout: 2)
        XCTAssertTrue(manager.title.isEmpty)
        XCTAssertTrue(manager.artist.isEmpty)
        XCTAssertNil(manager.artwork)
        XCTAssertEqual(manager.currentPosition, 0)
        subscription.cancel()
    }
}

private final class SnapshotExecutor: AppleScriptExecuting {
    var hasTrack = true

    func execute(_ source: String) -> String? {
        guard hasTrack else { return "NOT_PLAYING" }
        return ["Paused track", "Artist", "Album", "180000", "42", "false", "", "track-id"]
            .joined(separator: MusicScriptValue.separator)
    }
}

private struct SnapshotLocator: MusicApplicationLocating {
    func isRunning(_ application: MusicApplication) -> Bool {
        application.app == .spotify
    }
}
