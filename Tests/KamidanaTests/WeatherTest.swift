import Foundation
import XCTest

@testable import KamidanaApp

class WeatherTest: XCTestCase {

    @MainActor
    public func testfetchWeatherData() async throws {
        guard ProcessInfo.processInfo.environment["KAMIDANA_RUN_WEATHER_INTEGRATION_TESTS"] == "1" else {
            throw XCTSkip("Live weather integration tests are disabled")
        }
        let ins = WeatherManager()
        let response = await ins.fetchWeatherData()
        switch response {
        case .success(let info): XCTAssertFalse(info.currentCondition.isEmpty)
        case .failure(let error): XCTFail(error.localizedDescription)
        }
    }
}
