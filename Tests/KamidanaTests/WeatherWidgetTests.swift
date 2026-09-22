import Foundation
import XCTest
@testable import KamidanaApp

final class WeatherWidgetTests: XCTestCase {
    private let json = #"""
    {
      "current_condition": [{
        "FeelsLikeC": "-5", "FeelsLikeF": "23", "cloudcover": "20", "humidity": "64",
        "observation_time": "10:00 AM", "precipInches": "0", "precipMM": "0",
        "pressure": "1013", "pressureInches": "30", "temp_C": "-2", "temp_F": "28",
        "uvIndex": "2", "visibility": "10", "visibilityMiles": "6", "weatherCode": "113",
        "weatherDesc": [{"value": "Sunny"}], "weatherIconUrl": [{"value": ""}],
        "winddir16Point": "N", "winddirDegree": "0", "windspeedKmph": "12", "windspeedMiles": "7"
      }],
      "nearest_area": [{
        "areaName": [{"value": "Test City"}], "country": [{"value": "Test Country"}],
        "latitude": "0", "longitude": "0", "population": "0", "region": [], "weatherUrl": []
      }],
      "request": [],
      "weather": [{
        "astronomy": [{"moon_illumination": "50", "moon_phase": "First Quarter",
          "moonrise": "12:00 PM", "moonset": "12:00 AM", "sunrise": "06:00 AM", "sunset": "06:00 PM"}],
        "avgtempC": "0", "avgtempF": "32", "date": "2026-09-21",
        "maxtempC": "5", "maxtempF": "41", "mintempC": "-2", "mintempF": "28",
        "sunHour": "8", "totalSnow_cm": "0", "uvIndex": "2",
         "hourly": [{"chanceofrain": "10", "weatherCode": "113", "weatherDesc": [{"value": "Sunny"}]}, {"chanceofrain": "70"}]
      }]
    }
    """#

    func testDecodesMixedCaseAndSnakeCaseKeysWithoutTranslations() throws {
        let info = try WeatherClient.decode(Data(json.utf8))
        XCTAssertEqual(info.currentCondition.first?.feelsLikeC, "-5")
        XCTAssertEqual(info.currentCondition.first?.tempC, "-2")
        XCTAssertEqual(info.nearestArea.first?.areaName.first?.value, "Test City")
        XCTAssertEqual(info.weather.first?.totalSnowCM, "0")
        XCTAssertEqual(info.weather.first?.astronomy.first?.moonPhase, "First Quarter")
    }

    func testRejectsMissingOrEmptyCurrentConditions() throws {
        XCTAssertThrowsError(try WeatherClient.decode(Data(#"{"error":"unavailable"}"#.utf8)))
        XCTAssertThrowsError(try WeatherClient.decode(Data(#"{"current_condition":[],"nearest_area":[],"request":[],"weather":[]}"#.utf8)))
    }

    func testFormatsAllValuesAndConvertsBothTemperaturesToKelvin() throws {
        let info = try WeatherClient.decode(Data(json.utf8))
        let celsius = WeatherPresentation(info: info, config: WeatherWidgetConfig())
        XCTAssertEqual(celsius.value(.temperature), "-2.0 °C")
        XCTAssertEqual(celsius.value(.feelsLike), "-5.0 °C")
        XCTAssertEqual(celsius.value(.humidity), "64%")
        XCTAssertEqual(celsius.value(.windSpeed), "12 km/h")
        XCTAssertEqual(celsius.value(.pressure), "1013 hPa")
        XCTAssertEqual(celsius.value(.description), "Sunny")
        let searchedLocation = WeatherPresentation(
            info: info,
            config: WeatherWidgetConfig(),
            locationOverride: "Paris"
        )
        XCTAssertEqual(searchedLocation.value(.city), "Paris")
        XCTAssertEqual(celsius.value(.chanceOfRain), "70%")
        XCTAssertEqual(celsius.forecast.count, 1)
        XCTAssertEqual(celsius.forecast.first?.precipitationChance, "70")
        XCTAssertEqual(celsius.forecast.first?.description, "Sunny")
        let kelvin = WeatherPresentation(info: info, config: WeatherWidgetConfig(
            display: WeatherDisplayConfig(temperatureUnit: .kelvin)))
        XCTAssertEqual(kelvin.value(.temperature), "271.15 K")
        XCTAssertEqual(kelvin.value(.feelsLike), "268.15 K")
    }

    func testConfiguredFormatsColorsAndIconsAreSharedByCompactValues() throws {
        let info = try WeatherClient.decode(Data(json.utf8))
        let config = WeatherWidgetConfig(
            icons: [KamidanaWeatherIconConfig(sun: "custom-sun")],
            colors: [KamidanaWeatherColorConfig(sun: "#fab387")],
            display: WeatherDisplayConfig(
                formats: ["temperature": "T={value}{unit}", "humidity": "RH {value}%"],
                colors: ["temperature": "#89b4fa"]))
        let presentation = WeatherPresentation(info: info, config: config)
        let parts = presentation.parts(format: "{weather} {temperature} {humidity} {description}")
        XCTAssertEqual(parts.map(\.text).joined(), "custom-sun T=-2.0°C RH 64% Sunny")
        XCTAssertEqual(parts[2].text, presentation.value(.temperature))
        XCTAssertEqual(parts[2].field, .temperature)
        XCTAssertEqual(presentation.colorHex(.weather), "#fab387")
        XCTAssertEqual(presentation.colorHex(.temperature), "#89b4fa")
    }

    func testUnknownConditionsAndMissingDataDoNotShowFabricatedMeasurements() {
        let presentation = WeatherPresentation(info: nil, config: WeatherWidgetConfig())
        XCTAssertEqual(presentation.condition, .unknown)
        for field: WeatherValue in [.temperature, .feelsLike, .humidity, .windSpeed, .pressure, .chanceOfRain] {
            XCTAssertEqual(presentation.value(field), "--")
        }
        XCTAssertEqual(WeatherCondition(code: "113"), .sun)
        XCTAssertEqual(WeatherCondition(code: "116"), .cloud)
        XCTAssertEqual(WeatherCondition(code: "296"), .rain)
        XCTAssertEqual(WeatherCondition(code: "389"), .thunderRain)
        XCTAssertEqual(WeatherCondition(code: "338"), .snow)
        XCTAssertEqual(WeatherCondition(code: "invalid"), .unknown)
    }

    func testURLSafelyEncodesLocationAndUsesHourlyForecasts() throws {
        let url = try XCTUnwrap(WeatherClient.url(location: "New York?test=1&x=2", lang: "fr"))
        let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
        XCTAssertEqual(components.host, "wttr.in")
        XCTAssertEqual(components.path, "/New York?test=1&x=2")
        XCTAssertEqual(components.queryItems?.count, 2)
        XCTAssertEqual(components.queryItems?.first?.value, "j1")
        XCTAssertEqual(components.queryItems?.last?.value, "fr")
    }

    func testDecodesLocationCandidatesWithDisplayDetails() throws {
        let data = Data(
            #"{"results":[{"name":"Paris","country":"France","admin1":"Ile-de-France"},{"name":"Paris","country":"United States"}]}"#.utf8
        )

        let response = try JSONDecoder().decode(LocationResponse.self, from: data)

        XCTAssertEqual(response.results.count, 2)
        XCTAssertEqual(response.results[0].locationDetail, "Ile-de-France, France")
        XCTAssertEqual(response.results[1].locationDetail, "United States")
    }

    @MainActor
    func testRefreshRetainsPreviousDataOnFailureAndRecovers() async throws {
        let info = try WeatherClient.decode(Data(json.utf8))
        var count = 0
        let manager = WeatherManager { _, _ in
            count += 1
            return count == 2 ? .failure(.networkError("Offline")) : .success(info)
        }
        await manager.refresh()
        XCTAssertNotNil(manager.info)
        await manager.refresh()
        XCTAssertNotNil(manager.error)
        XCTAssertEqual(manager.info?.currentCondition.first?.tempC, "-2")
        await manager.refresh()
        XCTAssertNil(manager.error)
        XCTAssertFalse(manager.isLoading)
    }

    @MainActor
    func testCancellationStopsPollingWithoutPublishingFailure() async {
        let started = expectation(description: "Request started")
        var count = 0
        let manager = WeatherManager { _, _ in
            count += 1
            started.fulfill()
            do { try await Task.sleep(nanoseconds: 60_000_000_000) } catch {}
            return .failure(.networkError("Cancelled"))
        }
        let task = Task { await manager.monitor(config: WeatherWidgetConfig(polling: 60)) }
        await fulfillment(of: [started], timeout: 2)
        task.cancel()
        await task.value
        XCTAssertEqual(count, 1)
        XCTAssertNil(manager.error)
        XCTAssertNil(manager.info)
        XCTAssertFalse(manager.isLoading)
    }
}
