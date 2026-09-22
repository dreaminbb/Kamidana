import AppKit
import Combine
import Foundation

enum WeatherData {
    case success(WeatherInfo)
    case failure(WeatherError)

    enum CodingKeys: String, CodingKey {
        case success
        case failure
    }
}

enum WeatherError: Error, LocalizedError {
    case scriptFailed(String)
    case networkError(String)
    case decodingError(String)

    var errorDescription: String? {
        switch self {
        case .scriptFailed(let msg):
            return msg

        case .networkError(let msg):
            return msg
        case .decodingError(let msg):
            return msg
        }
    }
}

struct WeatherInfo: Codable {
    let currentCondition: [CurrentCondition]
    let nearestArea: [NearestArea]
    let request: [Request]
    let weather: [Weather]

    enum CodingKeys: String, CodingKey {
        case currentCondition = "current_condition"
        case nearestArea = "nearest_area"
        case request = "request"
        case weather = "weather"
    }
}

// MARK: - CurrentCondition
struct CurrentCondition: Codable {
    let feelsLikeC: String
    let feelsLikeF: String
    let cloudcover: String
    let humidity: String
    let observationTime: String
    let precipInches: String
    let precipMM: String
    let pressure: String
    let pressureInches: String
    let tempC: String
    let tempF: String
    let uvIndex: String
    let visibility: String
    let visibilityMiles: String
    let weatherCode: String
    let weatherDesc: [WeatherDesc]
    let weatherIconURL: [WeatherDesc]
    let winddir16Point: String
    let winddirDegree: String
    let windspeedKmph: String
    let windspeedMiles: String

    enum CodingKeys: String, CodingKey {
        case feelsLikeC = "FeelsLikeC"
        case feelsLikeF = "FeelsLikeF"
        case cloudcover = "cloudcover"
        case humidity = "humidity"
        case observationTime = "observation_time"
        case precipInches = "precipInches"
        case precipMM = "precipMM"
        case pressure = "pressure"
        case pressureInches = "pressureInches"
        case tempC = "temp_C"
        case tempF = "temp_F"
        case uvIndex = "uvIndex"
        case visibility = "visibility"
        case visibilityMiles = "visibilityMiles"
        case weatherCode = "weatherCode"
        case weatherDesc = "weatherDesc"
        case weatherIconURL = "weatherIconUrl"
        case winddir16Point = "winddir16Point"
        case winddirDegree = "winddirDegree"
        case windspeedKmph = "windspeedKmph"
        case windspeedMiles = "windspeedMiles"
    }
}

// MARK: - WeatherDesc
struct WeatherDesc: Codable {
    let value: String

    enum CodingKeys: String, CodingKey {
        case value = "value"
    }
}

// MARK: - NearestArea
struct NearestArea: Codable {
    let areaName: [WeatherDesc]
    let country: [WeatherDesc]
    let latitude: String
    let longitude: String
    let population: String
    let region: [WeatherDesc]
    let weatherURL: [WeatherDesc]

    enum CodingKeys: String, CodingKey {
        case areaName = "areaName"
        case country = "country"
        case latitude = "latitude"
        case longitude = "longitude"
        case population = "population"
        case region = "region"
        case weatherURL = "weatherUrl"
    }
}

// MARK: - Request
struct Request: Codable {
    let query: String
    let type: String

    enum CodingKeys: String, CodingKey {
        case query = "query"
        case type = "type"
    }
}

// MARK: - Weather
struct Weather: Codable {
    let astronomy: [Astronomy]
    let avgtempC: String
    let avgtempF: String
    let date: String
    let maxtempC: String
    let maxtempF: String
    let mintempC: String
    let mintempF: String
    let sunHour: String
    let totalSnowCM: String
    let uvIndex: String
    let hourly: [WeatherHour]?

    enum CodingKeys: String, CodingKey {
        case astronomy = "astronomy"
        case avgtempC = "avgtempC"
        case avgtempF = "avgtempF"
        case date = "date"
        case maxtempC = "maxtempC"
        case maxtempF = "maxtempF"
        case mintempC = "mintempC"
        case mintempF = "mintempF"
        case sunHour = "sunHour"
        case totalSnowCM = "totalSnow_cm"
        case uvIndex = "uvIndex"
        case hourly
    }
}

struct WeatherHour: Codable {
    let chanceofrain: String?
    let tempC: String?
    let weatherCode: String?
    let weatherDesc: [WeatherDesc]?

    enum CodingKeys: String, CodingKey {
        case chanceofrain
        case tempC = "tempC"
        case weatherCode
        case weatherDesc
    }
}

// MARK: - Astronomy
struct Astronomy: Codable {
    let moonIllumination: String
    let moonPhase: String
    let moonrise: String
    let moonset: String
    let sunrise: String
    let sunset: String

    enum CodingKeys: String, CodingKey {
        case moonIllumination = "moon_illumination"
        case moonPhase = "moon_phase"
        case moonrise = "moonrise"
        case moonset = "moonset"
        case sunrise = "sunrise"
        case sunset = "sunset"
    }
}

enum WeatherClient {
    static func url(location: String, lang: String) -> URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "wttr.in"
        components.path = "/\(location)"
        // j1 includes hourly rain probabilities; j2 omits hourly forecasts.
        components.queryItems = [
            URLQueryItem(name: "format", value: "j1"),
            URLQueryItem(name: "lang", value: lang),
        ]
        return components.url
    }

    static func decode(_ data: Data) throws -> WeatherInfo {
        // Explicit CodingKeys must be used with the default key decoding strategy.
        let info = try JSONDecoder().decode(WeatherInfo.self, from: data)
        guard !info.currentCondition.isEmpty else {
            throw WeatherError.decodingError("The weather response contains no current conditions.")
        }
        return info
    }

    static func fetch(location: String, lang: String) async -> Result<WeatherInfo, WeatherError> {
        guard let url = url(location: location, lang: lang) else {
            return .failure(.networkError("Invalid weather URL."))
        }
        do {
            print("[DEBUG] Weather Widget, weather API URL: \(url.absoluteString)")
            let (data, response) = try await URLSession.shared.data(
                for: URLRequest(url: url, timeoutInterval: 20))
            guard let response = response as? HTTPURLResponse, response.statusCode == 200 else {
                return .failure(.networkError("The weather service is unavailable."))
            }
            do {
                return .success(try decode(data))
            } catch {
                return .failure(.decodingError("Invalid weather response: \(error)"))
            }
        } catch {
            return .failure(.networkError(error.localizedDescription))
        }
    }
}

struct LocationResponse: Codable {
    let results: [LocationResult]
}

struct LocationResult: Codable {
    let name: String
    let country: String?
    let admin1: String?

    var locationDetail: String? {
        let components = [admin1, country].compactMap { $0 }.filter { !$0.isEmpty }
        return components.isEmpty ? nil : components.joined(separator: ", ")
    }
}

enum LocationService {
    static func fetchLocations(name: String, lang: String) async throws -> [LocationResult] {
        guard
            var components = URLComponents(string: "https://geocoding-api.open-meteo.com/v1/search")
        else {
            throw WeatherError.networkError("Invalid location URL.")
        }
        components.queryItems = [
            URLQueryItem(name: "name", value: name),
            URLQueryItem(name: "count", value: "5"),
            URLQueryItem(name: "language", value: lang),
            URLQueryItem(name: "format", value: "json"),
        ]
        guard let url = components.url else {
            throw WeatherError.networkError("Invalid location URL.")
        }

        print("[DEBUG] Weather Widget, geolocation API search URL: \(url.absoluteString)")

        do {
            let (data, response) = try await URLSession.shared.data(
                for: URLRequest(url: url, timeoutInterval: 20))
            guard let response = response as? HTTPURLResponse, response.statusCode == 200 else {
                throw WeatherError.networkError("The location service is unavailable.")
            }
            do {
                let locationResponse = try JSONDecoder().decode(LocationResponse.self, from: data)
                return Array(locationResponse.results.prefix(5))
            } catch {
                throw WeatherError.decodingError("Invalid location response: \(error)")
            }
        } catch let error as WeatherError {
            throw error
        } catch {
            if Task.isCancelled {
                throw CancellationError()
            }
            throw WeatherError.networkError(error.localizedDescription)
        }
    }

    static func fetchLocation(name: String, lang: String) async throws -> String {
        guard let firstLocation = try await fetchLocations(name: name, lang: lang).first else {
            throw WeatherError.decodingError("No locations found in the response.")
        }
        return firstLocation.name
    }
}

@MainActor
final class WeatherManager: ObservableObject {
    @Published private(set) var info: WeatherInfo?
    @Published private(set) var isLoading = false
    @Published private(set) var error: WeatherError?

    var location = ""
    var lang = "en"
    @Published var userSelectedLocation = ""
    private let fetch: (String, String) async -> Result<WeatherInfo, WeatherError>
    private var activeRequestID: UUID?

    init(
        fetch: @escaping (String, String) async -> Result<WeatherInfo, WeatherError> = WeatherClient
            .fetch
    ) {
        self.fetch = fetch
    }

    func resolveWeatherProviderURL() -> String {
        WeatherClient.url(
            location: userSelectedLocation.isEmpty ? location : userSelectedLocation, lang: lang)?
            .absoluteString ?? ""
    }

    func fetchWeatherData() async -> Result<WeatherInfo, WeatherError> {
        await fetch(userSelectedLocation.isEmpty ? location : userSelectedLocation, lang)
    }

    func refresh() async {

        let requestID = UUID()
        activeRequestID = requestID
        isLoading = true
        defer {
            if activeRequestID == requestID { isLoading = false }
        }
        let response = await fetchWeatherData()
        guard !Task.isCancelled, activeRequestID == requestID else { return }
        switch response {
        case .success(let info):
            guard !info.currentCondition.isEmpty else {
                error = .decodingError("The weather response contains no current conditions.")
                return
            }
            self.info = info
            error = nil
        case .failure(let error):
            // Keep the last successful snapshot visible when a refresh fails.
            self.error = error
        }
    }

    /// Owned by SwiftUI's task lifecycle; disappears and config reloads cancel polling.
    func monitor(config: WeatherWidgetConfig) async {
        if location != config.display.location || lang != config.lang {
            info = nil
            error = nil
        }
        location = config.display.location
        lang = config.lang
        let interval = config.polling ?? 60
        let seconds = interval.isFinite && interval > 0 ? min(interval, 86_400 * 365) : 60
        while !Task.isCancelled {
            await refresh()
            do {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            } catch {
                return
            }
        }
    }
}
