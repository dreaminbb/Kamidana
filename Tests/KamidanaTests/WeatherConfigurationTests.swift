import XCTest
@testable import KamidanaApp

final class WeatherConfigurationTests: XCTestCase {
    private let yaml = """
    global:
      style:
        color: "#ffffff"
      popup_style:
        corner_radius: 16
    center:
      center_default: clock
      widgets:
        - id: clock
          type: clock
          format: "{time}"
    left:
      animation: static
      widgets:
        - id: weather
          type: weather
          polling: 60
          format: "{weather} {temperature} {humidity}"
          weather_display:
            temperature_unit: K
            location: "New York"
            formats:
              temperature: "{value}{unit}"
              humidity: "RH {value}%"
            colors:
              temperature: "#fab387"
          icon:
            - sun: "sun-icon"
          color:
            - sun: "#fab387"
    """

    func testConfigurationFlowsThroughAdapterAndRegistry() throws {
        let configuration = try KamidanaConfigurationV1Decoder.decode(yaml: yaml)
        let runtime = KamidanaConfigurationV1Adapter.makeLegacyConfig(from: configuration)
        for layout in [runtime.externalDisplay, runtime.builtInDisplay] {
            let widget = try XCTUnwrap(layout.left.first)
            let config = try XCTUnwrap(widget.config as? WeatherWidgetConfig)
            XCTAssertEqual(widget.id, "weather")
            XCTAssertEqual(widget.v1Activate, .click)
            XCTAssertEqual(widget.v1Animation, .static)
            XCTAssertEqual(widget.v1Style?.color, "#ffffff")
            XCTAssertEqual(widget.popupTheme?.cornerRadius, 16)
            XCTAssertEqual(config.display.temperatureUnit, .kelvin)
            XCTAssertEqual(config.display.formats["humidity"], "RH {value}%")
            XCTAssertEqual(config.display.colors["temperature"], "#fab387")
            XCTAssertEqual(config.display.location, "New York")
            XCTAssertEqual(config.polling, 60)
        }
        WidgetRegistry.shared.registerAllWidgets()
        let factory = try XCTUnwrap(WidgetRegistry.shared.factory(for: "weather"))
        XCTAssertEqual(factory.getTabName(config: WeatherWidgetConfig()), "Weather")
    }

    func testRejectsUnsupportedUnitsInvalidValueFieldsAndPolling() {
        for invalid in [
            yaml.replacingOccurrences(of: "temperature_unit: K", with: "temperature_unit: F"),
            yaml.replacingOccurrences(of: "polling: 60", with: "polling: 0"),
            yaml.replacingOccurrences(of: "polling: 60", with: "polling: .inf"),
            yaml.replacingOccurrences(of: "humidity: \"RH {value}%\"", with: "unknown: \"{value}\""),
            yaml.replacingOccurrences(of: "temperature: \"#fab387\"", with: "temperature: \"invalid\""),
            yaml.replacingOccurrences(of: "type: weather", with: "type: clock"),
        ] {
            XCTAssertThrowsError(try KamidanaConfigurationV1Decoder.decode(yaml: invalid))
        }
    }

    func testRejectsWeatherInsideBelowFolder() throws {
        var configuration = try KamidanaConfigurationV1Decoder.decode(yaml: yaml)
        configuration.left.widgets = [KamidanaWidget(
            id: "folder", kind: .widgetFolder, direction: .below,
            widgets: configuration.left.widgets)]
        XCTAssertThrowsError(try configuration.validate()) { error in
            XCTAssertTrue(String(describing: error).contains("expanding widget 'weather'"))
        }
    }

    func testOmittedDisplayOptionsDefaultToCelsius() throws {
        let configuration = try KamidanaConfigurationV1Decoder.decode(yaml: """
        center:
          center_default: weather
          widgets:
            - id: weather
              type: weather
              format: "{temperature}"
              weather_display: {}
        """)
        let config = try XCTUnwrap(configuration.center.widgets.first?.weatherDisplay)
        XCTAssertEqual(config.temperatureUnit, .celsius)
        XCTAssertEqual(config.location, "")
        XCTAssertTrue(config.formats.isEmpty)
    }

    func testExistingRuntimeWeatherConfigDecodesWithoutDisplayOptions() throws {
        let config = try JSONDecoder().decode(WeatherWidgetConfig.self, from: Data(
            #"{"format":"{weather}","polling":60,"icons":[],"colors":[]}"#.utf8))
        XCTAssertEqual(config.display.temperatureUnit, .celsius)
        XCTAssertEqual(config.polling, 60)
    }
}
