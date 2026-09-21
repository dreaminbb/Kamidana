import Foundation

public enum WeatherTemperatureUnit: String, Codable, Hashable {
    case celsius = "C"
    case kelvin = "K"

    var symbol: String { self == .celsius ? "°C" : "K" }
}

public enum WeatherValue: String, CaseIterable {
    case temperature, weather, humidity
    case feelsLike = "feels_like"
    case windSpeed = "wind_speed"
    case pressure, description, city
    case chanceOfRain = "chance_of_rain"

    var defaultFormat: String {
        switch self {
        case .temperature, .feelsLike: return "{value} {unit}"
        case .humidity, .chanceOfRain: return "{value}%"
        case .windSpeed: return "{value} km/h"
        case .pressure: return "{value} hPa"
        default: return "{value}"
        }
    }
}

/// Per-value presentation shared by the compact label and weather details.
public struct WeatherDisplayConfig: Codable, Hashable {
    public var temperatureUnit: WeatherTemperatureUnit
    public var location: String
    public var formats: [String: String]
    public var colors: [String: String]

    public init(
        temperatureUnit: WeatherTemperatureUnit = .celsius,
        location: String = "",
        formats: [String: String] = [:],
        colors: [String: String] = [:]
    ) {
        self.temperatureUnit = temperatureUnit
        self.location = location
        self.formats = formats
        self.colors = colors
    }

    private enum CodingKeys: String, CodingKey {
        case temperatureUnit = "temperature_unit"
        case location, formats, colors
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            temperatureUnit: try container.decodeIfPresent(WeatherTemperatureUnit.self, forKey: .temperatureUnit) ?? .celsius,
            location: try container.decodeIfPresent(String.self, forKey: .location) ?? "",
            formats: try container.decodeIfPresent([String: String].self, forKey: .formats) ?? [:],
            colors: try container.decodeIfPresent([String: String].self, forKey: .colors) ?? [:]
        )
    }

    func validate(path: String) throws {
        for key in Set(formats.keys).union(colors.keys) where WeatherValue(rawValue: key) == nil {
            throw KamidanaConfigurationV1Error.invalidWidget(path: path, reason: "Unknown weather value '\(key)'")
        }
        for (key, format) in formats where format.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw KamidanaConfigurationV1Error.invalidWidget(path: path, reason: "formats.\(key) must be non-empty")
        }
        for (key, color) in colors {
            let digits = color.dropFirst()
            guard color.hasPrefix("#"), [6, 8].contains(digits.count),
                digits.allSatisfy({ $0.isASCII && $0.isHexDigit }) else {
                throw KamidanaConfigurationV1Error.invalidWidget(path: path, reason: "colors.\(key) must be #RRGGBB or #AARRGGBB")
            }
        }
    }
}
