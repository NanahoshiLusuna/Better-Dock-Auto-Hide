import CoreLocation
import Foundation

struct WeatherSnapshot {
    let temperatureText: String
    let symbolName: String
}

final class WeatherMonitor: NSObject, CLLocationManagerDelegate {
    var onUpdate: ((WeatherSnapshot) -> Void)?

    private let manager = CLLocationManager()
    private let defaults = UserDefaults.standard
    private var didRequestAuthorization = false
    private var refreshTimer: Timer?

    func start() {
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
        handle(manager.authorizationStatus)
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 20 * 60, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.handle(self.manager.authorizationStatus)
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        handle(manager.authorizationStatus)
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        defaults.set(location.coordinate.latitude, forKey: "lastLatitude")
        defaults.set(location.coordinate.longitude, forKey: "lastLongitude")
        fetch(location.coordinate)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        useSavedOrIPLocation()
    }

    private func handle(_ status: CLAuthorizationStatus) {
        switch status {
        case .notDetermined:
            guard !didRequestAuthorization else { return }
            didRequestAuthorization = true
            manager.requestWhenInUseAuthorization()
        case .authorized, .authorizedAlways:
            manager.requestLocation()
        default:
            useSavedOrIPLocation()
        }
    }

    private func useSavedOrIPLocation() {
        if let latitude = defaults.object(forKey: "lastLatitude") as? Double,
           let longitude = defaults.object(forKey: "lastLongitude") as? Double {
            fetch(CLLocationCoordinate2D(latitude: latitude, longitude: longitude))
            return
        }
        guard let url = URL(string: "https://ipwho.is/") else { return }
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let latitude = json["latitude"] as? Double,
                  let longitude = json["longitude"] as? Double
            else { return }
            self?.fetch(CLLocationCoordinate2D(latitude: latitude, longitude: longitude))
        }.resume()
    }

    private func fetch(_ coordinate: CLLocationCoordinate2D) {
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")
        components?.queryItems = [
            URLQueryItem(name: "latitude", value: String(coordinate.latitude)),
            URLQueryItem(name: "longitude", value: String(coordinate.longitude)),
            URLQueryItem(name: "current", value: "temperature_2m,weather_code,is_day"),
            URLQueryItem(name: "timezone", value: "auto"),
        ]
        guard let url = components?.url else { return }
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let self, let data, let snapshot = Self.snapshot(from: data) else { return }
            DispatchQueue.main.async { self.onUpdate?(snapshot) }
        }.resume()
    }

    private static func snapshot(from data: Data) -> WeatherSnapshot? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let current = json["current"] as? [String: Any],
              let temperature = current["temperature_2m"] as? Double,
              let code = number(current["weather_code"]),
              let isDay = number(current["is_day"])
        else { return nil }
        return WeatherSnapshot(
            temperatureText: "\(Int(temperature.rounded()))°",
            symbolName: symbolName(code: code, isDay: isDay == 1)
        )
    }

    private static func symbolName(code: Int, isDay: Bool) -> String {
        switch code {
        case 51...67, 71...82, 95...99:
            return "cloud.rain.fill"
        case 2, 3, 45, 48:
            return "cloud.fill"
        default:
            return isDay ? "sun.max.fill" : "moon.stars.fill"
        }
    }

    private static func number(_ value: Any?) -> Int? {
        if let value = value as? Int { return value }
        if let value = value as? Double { return Int(value) }
        return nil
    }
}
