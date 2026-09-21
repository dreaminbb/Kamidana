import Foundation
import XCTest

@testable import KamidanaApp

class WeatherTest: XCTestCase {

    public func testfetchWeatherData() async {

        guard let url = URL(string: WeatherManager().resolveWeatherProviderURL()) else {
            return print("Invalid URL")
        }
        let ins = WeatherManager()

        let response = await ins.fetchWeatherData()
        print(response)

    }
}
