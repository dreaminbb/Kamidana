import Foundation
import XCTest

@testable import KamidanaApp

final class MusicPlayerControllerTests: XCTestCase {
    func testSpotifyParsesPlaybackInformation() throws {
        let separator = MusicScriptValue.separator
        let output = [
            "Track",
            "Artist",
            "Album",
            "215000",
            "12,5",
            "true",
            "https://example.com/artwork.jpg",
            "spotify:track:123",
        ].joined(separator: separator)

        let snapshot = try XCTUnwrap(SpotifyMusicController.parse(output: output))

        XCTAssertEqual(snapshot.app, .spotify)
        XCTAssertEqual(snapshot.title, "Track")
        XCTAssertEqual(snapshot.artist, "Artist")
        XCTAssertEqual(snapshot.album, "Album")
        XCTAssertEqual(snapshot.duration, 215)
        XCTAssertEqual(snapshot.currentPosition, 12.5)
        XCTAssertTrue(snapshot.isPlaying)
        XCTAssertEqual(snapshot.sourceIdentifier, "spotify:track:123")
        XCTAssertEqual(
            snapshot.artworkURL,
            URL(string: "https://example.com/artwork.jpg")
        )
    }

    func testAppleMusicParsesPausedPlaybackInformation() throws {
        let separator = MusicScriptValue.separator
        let output = [
            "Track",
            "Artist",
            "Album",
            "180,25",
            "42,75",
            "false",
            "987654321",
        ].joined(separator: separator)

        let snapshot = try XCTUnwrap(AppleMusicController.parse(output: output))

        XCTAssertEqual(snapshot.app, .appleMusic)
        XCTAssertEqual(snapshot.duration, 180.25)
        XCTAssertEqual(snapshot.currentPosition, 42.75)
        XCTAssertFalse(snapshot.isPlaying)
        XCTAssertEqual(snapshot.sourceIdentifier, "987654321")
    }

    func testControllersRejectMissingPlaybackInformation() {
        XCTAssertNil(SpotifyMusicController.parse(output: "NOT_PLAYING"))
        XCTAssertNil(SpotifyMusicController.parse(output: "incomplete"))
        XCTAssertNil(AppleMusicController.parse(output: "NOT_PLAYING"))
        XCTAssertNil(AppleMusicController.parse(output: "incomplete"))
    }

    func testControllerDoesNotExecuteScriptWhenApplicationIsNotRunning() {
        let executor = StubAppleScriptExecutor(output: nil)
        let controller = SpotifyMusicController(
            executor: executor,
            locator: StubMusicApplicationLocator(runningResult: false)
        )

        XCTAssertNil(controller.fetchNowPlayingInfo())
        controller.togglePlayPause()
        controller.changeTrack(direction: .next)
        controller.seek(to: 30)

        XCTAssertTrue(executor.executedSources.isEmpty)
    }

    func testSpotifyCommandsContainResolvedValues() {
        let executor = StubAppleScriptExecutor(output: nil)
        let controller = SpotifyMusicController(
            executor: executor,
            locator: StubMusicApplicationLocator(runningResult: true)
        )

        controller.changeTrack(direction: .next)
        controller.seek(to: 12.5)
        controller.skip(by: -10)

        XCTAssertTrue(executor.executedSources[0].contains("next track"))
        XCTAssertTrue(executor.executedSources[1].contains("12.500"))
        XCTAssertTrue(executor.executedSources[2].contains("+ -10"))
        XCTAssertTrue(
            executor.executedSources.allSatisfy { $0.contains("launch") }
        )
    }

    func testAppleMusicArtworkIsFetchedOncePerTrack() throws {
        let separator = MusicScriptValue.separator
        let output = [
            "Track",
            "Artist",
            "Album",
            "180",
            "42",
            "true",
            "track-id",
        ].joined(separator: separator)
        let artworkData = Data([0x01, 0x02])
        let executor = StubAppleScriptExecutor(
            output: output,
            rawOutput: artworkData
        )
        let controller = AppleMusicController(
            executor: executor,
            locator: StubMusicApplicationLocator(runningResult: true)
        )

        let firstSnapshot = try XCTUnwrap(controller.fetchNowPlayingInfo())
        let secondSnapshot = try XCTUnwrap(controller.fetchNowPlayingInfo())

        XCTAssertEqual(firstSnapshot.artworkData, artworkData)
        XCTAssertEqual(secondSnapshot.artworkData, artworkData)
        XCTAssertEqual(executor.rawExecutionCount, 1)
    }

    func testLiveSpotifyPlaybackWhenExplicitlyEnabled() throws {
        guard
            ProcessInfo.processInfo.environment[
                "KAMIDANA_RUN_MUSIC_INTEGRATION_TESTS"
            ] == "1"
        else {
            throw XCTSkip("Live music integration tests are disabled")
        }

        let locator = SystemMusicApplicationLocator()
        guard locator.isRunning(.spotify) else {
            throw XCTSkip("Spotify is not running")
        }

        let controller = SpotifyMusicController(
            executor: OsaScriptExecutor(),
            locator: locator
        )
        let snapshot = try XCTUnwrap(controller.fetchNowPlayingInfo())

        XCTAssertFalse(snapshot.title.isEmpty)
        XCTAssertFalse(snapshot.artist.isEmpty)
        XCTAssertGreaterThan(snapshot.duration, 0)
    }
}

private final class StubAppleScriptExecutor: AppleScriptExecuting {
    let output: String?
    let rawOutput: Data?
    private(set) var executedSources: [String] = []
    private(set) var rawExecutionCount = 0

    init(output: String?, rawOutput: Data? = nil) {
        self.output = output
        self.rawOutput = rawOutput
    }

    func execute(_ source: String) -> String? {
        executedSources.append(source)
        return output
    }

    func executeRaw(_ source: String) -> Data? {
        rawExecutionCount += 1
        return rawOutput
    }
}

private struct StubMusicApplicationLocator: MusicApplicationLocating {
    let runningResult: Bool

    func isRunning(_ application: MusicApplication) -> Bool {
        runningResult
    }
}
