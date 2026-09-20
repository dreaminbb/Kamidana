import AppKit
import Combine
import Foundation


enum WeatherData: Codable {
}

enum WeatherError: Error, LocalizedError {
    case scriptFailed(String)

    var errorDescription: String? {
        switch self {
        case .scriptFailed(let msg):
            return msg
        }
    }
}

class WeatherManager: ObservableObject {

    static let weatherProviderURL: String = "https://wttr.in/"
    var location: String = ""  // Default use IP-based location, but when user selects a location from search region, this will be set to that location.


    public fetchWeatherData() -> Result<
}
