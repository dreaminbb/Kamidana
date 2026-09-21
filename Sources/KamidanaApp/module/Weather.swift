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

    var errorDescription: String? {
        switch self {
        case .scriptFailed(let msg):
            return msg

        case .networkError(let msg):
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

class WeatherManager: ObservableObject {

    let waatherProviderURLFormat: String = "format=j2"
    // format: %l: location, %c: condition, %t: temperature, %f: feels like temperature, %h: humidity, %w: wind, %p: precipitation, %P: pressure, %m: moon phase, %M: moon age, %u: uv, %S raising sun, %S: sunset time, %s: day length

    var location: String = "Tokyo"  // Default use IP-based location, but when user selects a location from search region, this will be set to that location.
    var userSelectedLocation: String = ""  // This will be set when user selects a location from search region.
    var lang = "en"  // use can't change this value, because all structures are defined in English, so if you change this value to "ja", the JSONDecoder will fail to decode the response.

    public func resolveWeatherProviderURL() -> String {
        if !userSelectedLocation.isEmpty {
            location = userSelectedLocation
        }
        return "https://wttr.in/\(location)?\(waatherProviderURLFormat)&lang=\(lang)"
    }

    private func jsonDecodResponseData(_ data: Data) -> WeatherInfo? {
        let decoder = JSONDecoder()
        do {
            let weatherResponse = try decoder.decode(WeatherInfo.self, from: data)
            return weatherResponse
        } catch {
            print("JSONデコードエラー: \(error)")
            return nil
        }
    }

    public func fetchWeatherData() async -> Result<WeatherInfo, WeatherError> {

        guard let url = URL(string: self.resolveWeatherProviderURL()) else {
            return .failure(.networkError("Invalid URL"))
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse,
                httpResponse.statusCode == 200
            else {
                print("サーバーエラー")
                return .failure(.networkError("Server error"))
            }

            guard let decodedResponse = jsonDecodResponseData(data) else {
                return .failure(.networkError("Invalid weather response"))
            }
            print("通信成功: \(decodedResponse)")
            return .success(decodedResponse)

        } catch {
            print("通信失敗: \(error.localizedDescription)")
            return .failure(.networkError(error.localizedDescription))
        }
    }
}
