import Foundation

enum WeatherCondition: String {
    case sun, cloud, rain, thunderRain, snow, unknown

    init(code: String?) {
        switch code.flatMap(Int.init) {
        case 113: self = .sun
        case 116, 119, 122, 143, 248, 260: self = .cloud
        case 200, 386, 389, 392, 395: self = .thunderRain
        case 179, 182, 185, 227, 230, 317, 320, 323, 326, 329, 332, 335, 338,
             350, 362, 365, 368, 371, 374, 377: self = .snow
        case 176, 263, 266, 281, 284, 293, 296, 299, 302, 305, 308, 311, 314,
             353, 356, 359: self = .rain
        default: self = .unknown
        }
    }

    var defaultIcon: String {
        switch self {
        case .sun: return "\u{f522}"
        case .cloud: return "\u{f0c2}"
        case .rain: return "\u{e239}"
        case .thunderRain: return "\u{e31d}"
        case .snow: return "\u{f0717}"
        case .unknown: return "\u{f128}"
        }
    }

    func icon(in config: KamidanaWeatherIconConfig) -> String? {
        switch self {
        case .sun: return config.sun
        case .cloud: return config.cloud
        case .rain: return config.rain
        case .thunderRain: return config.thunderRain
        case .snow: return config.snow
        case .unknown: return nil
        }
    }

    func color(in config: KamidanaWeatherColorConfig) -> String? {
        switch self {
        case .sun: return config.sun
        case .cloud: return config.cloud
        case .rain, .thunderRain: return config.rain
        case .snow: return config.snow
        case .unknown: return nil
        }
    }
}

/// A single formatting source for collapsed and expanded weather UI.
struct WeatherPresentation {
    let config: WeatherWidgetConfig
    let condition: WeatherCondition
    let rawValues: [String: String]
    let forecast: [ForecastDay]

    struct ForecastDay {
        let date: String
        let minimumTemperature: String
        let maximumTemperature: String
        let precipitationChance: String
        let description: String
        let icon: String
    }

    init(info: WeatherInfo?, config: WeatherWidgetConfig, locationOverride: String? = nil) {
        self.config = config
        let current = info?.currentCondition.first
        let condition = WeatherCondition(code: current?.weatherCode)
        self.condition = condition
        let unit = config.display.temperatureUnit
        func temperature(_ value: String?) -> String {
            guard let value, let number = Double(value), number.isFinite else { return "--" }
            return String(format: unit == .kelvin ? "%.2f" : "%.1f", locale: Locale(identifier: "en_US_POSIX"),
                          unit == .kelvin ? number + 273.15 : number)
        }
        func number(_ value: String?) -> String {
            guard let value, let number = Double(value), number.isFinite else { return "--" }
            return value
        }
        let rain = info?.weather.first?.hourly?.compactMap { hour -> Double? in
            guard let value = hour.chanceofrain.flatMap(Double.init), value.isFinite,
                  (0...100).contains(value) else { return nil }
            return value
        }.max()
        let selectedLocation = locationOverride?.trimmingCharacters(in: .whitespacesAndNewlines)
        forecast = (info?.weather ?? []).prefix(3).map { day in
            let representativeHour = day.hourly?.first
            let forecastCondition = WeatherCondition(code: representativeHour?.weatherCode)
            let forecastIcon = config.icons.reversed().compactMap {
                forecastCondition.icon(in: $0)
            }.first ?? forecastCondition.defaultIcon
            let rain = day.hourly?.compactMap { hour -> Double? in
                guard let value = hour.chanceofrain.flatMap(Double.init), value.isFinite,
                      (0...100).contains(value) else { return nil }
                return value
            }.max()
            return ForecastDay(
                date: day.date,
                minimumTemperature: temperature(day.mintempC),
                maximumTemperature: temperature(day.maxtempC),
                precipitationChance: rain.map { String(format: "%.0f", $0) } ?? "--",
                description: representativeHour?.weatherDesc?.first?.value ?? "Unavailable",
                icon: forecastIcon
            )
        }
        rawValues = [
            "temperature": temperature(current?.tempC),
            "weather": config.icons.reversed().compactMap { condition.icon(in: $0) }.first ?? condition.defaultIcon,
            "humidity": number(current?.humidity),
            "feels_like": temperature(current?.feelsLikeC),
            "wind_speed": number(current?.windspeedKmph),
            "pressure": number(current?.pressure),
            "description": current?.weatherDesc.first?.value ?? "Unavailable",
            "city": selectedLocation.flatMap { $0.isEmpty ? nil : $0 }
                ?? info?.nearestArea.first?.areaName.first?.value
                ?? (config.display.location.isEmpty ? "Current location" : config.display.location),
            "chance_of_rain": rain.map { String(format: "%.0f", $0) } ?? "--",
        ]
    }

    var icon: String { rawValues["weather"] ?? condition.defaultIcon }

    func value(_ field: WeatherValue) -> String {
        let raw = rawValues[field.rawValue] ?? "--"
        guard raw != "--" else { return raw }
        return KamidanaFormatRenderer.render(
            config.display.formats[field.rawValue] ?? field.defaultFormat,
            values: ["value": raw, "unit": config.display.temperatureUnit.symbol]
        )
    }

    func colorHex(_ field: WeatherValue) -> String? {
        if let color = config.display.colors[field.rawValue] { return color }
        guard field == .weather else { return nil }
        return config.colors.reversed().compactMap { condition.color(in: $0) }.first
    }

    struct Part {
        let text: String
        let field: WeatherValue?
    }

    /// Keep placeholder identity so each value can have its own color.
    func parts(format: String) -> [Part] {
        guard let expression = try? NSRegularExpression(pattern: #"\{([a-z_]+)\}"#) else {
            return [Part(text: format, field: nil)]
        }
        let source = format as NSString
        var cursor = 0
        var result: [Part] = []
        for match in expression.matches(in: format, range: NSRange(location: 0, length: source.length)) {
            if cursor < match.range.location {
                result.append(Part(text: source.substring(with: NSRange(location: cursor, length: match.range.location - cursor)), field: nil))
            }
            let field = WeatherValue(rawValue: source.substring(with: match.range(at: 1)))
            result.append(Part(text: field.map(value) ?? source.substring(with: match.range), field: field))
            cursor = NSMaxRange(match.range)
        }
        if cursor < source.length {
            result.append(Part(text: source.substring(from: cursor), field: nil))
        }
        return result
    }
}
