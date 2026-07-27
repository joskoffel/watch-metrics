@preconcurrency import CoreLocation
import Foundation
import WeatherKit
import WatchMetricsSupport

struct WeatherSummary: Equatable, Sendable {
    let emoji: String
    let symbolName: String
    let lowCelsius: Int
    let highCelsius: Int
    let description: String
    var briefText: String { "\(emoji) \(lowCelsius)–\(highCelsius) °C · \(description)" }
}

enum WeatherConditionMapper {
    static func summary(for condition: WeatherCondition, low: Double, high: Double) -> WeatherSummary {
        let kind: WeatherConditionKind
        switch condition {
        case .clear: kind = .clear
        case .mostlyClear, .partlyCloudy, .mostlyCloudy, .cloudy: kind = .cloudy
        case .rain, .drizzle, .heavyRain, .freezingRain: kind = .rain
        case .thunderstorms, .isolatedThunderstorms, .scatteredThunderstorms: kind = .thunderstorm
        case .snow, .flurries, .heavySnow, .blizzard: kind = .snow
        case .foggy, .haze, .smoky: kind = .fog
        default: kind = .cloudy
        }
        let presentation = WeatherPresentationMapper.presentation(for: kind)
        return WeatherSummary(emoji: presentation.emoji, symbolName: presentation.symbolName, lowCelsius: Int(low.rounded()), highCelsius: Int(high.rounded()), description: presentation.text)
    }
}

@MainActor final class WeatherBriefService {
    static let shared = WeatherBriefService()
    private let locationProvider = WeatherLocationProvider.shared
    private(set) var lastStatus = "Zatiaľ nenačítané"
    private(set) var lastSymbolName = "cloud.sun.fill"

    func currentSummary() async -> WeatherSummary? {
        guard let location = await locationProvider.usableLocation() else {
            recordStatus("Poloha nie je dostupná")
            return nil
        }

        return await withTaskGroup(of: WeatherSummary?.self) { group in
            group.addTask {
                do {
                    let weather = try await WeatherService.shared.weather(for: location)
                    guard let day = weather.dailyForecast.forecast.first else { return nil }
                    return WeatherConditionMapper.summary(
                        for: day.condition,
                        low: day.lowTemperature.converted(to: .celsius).value,
                        high: day.highTemperature.converted(to: .celsius).value
                    )
                } catch {
                    return nil
                }
            }
            group.addTask {
                try? await Task.sleep(for: .seconds(3))
                return nil
            }
            let result = await group.next() ?? nil
            group.cancelAll()
            if let result {
                recordStatus(result.briefText, symbolName: result.symbolName)
            } else {
                recordStatus("WeatherKit chyba alebo timeout")
            }
            return result
        }
    }

    private func recordStatus(_ status: String, symbolName: String = "cloud.sun.fill") {
        lastStatus = status
        lastSymbolName = symbolName
        BriefDiagnosticsStore().recordWeatherStatus(status)
    }
}

@MainActor final class WeatherLocationProvider: NSObject, CLLocationManagerDelegate {
    static let shared = WeatherLocationProvider()
    static let cacheFreshness: TimeInterval = 12 * 60 * 60
    private let manager = CLLocationManager()
    private let defaults = UserDefaults.standard
    private var continuation: CheckedContinuation<CLLocation?, Never>?
    override init() { super.init(); manager.delegate = self }
    func requestForegroundAuthorizationIfNeeded() {
        switch manager.authorizationStatus {
        case .notDetermined, .authorizedWhenInUse:
            manager.requestAlwaysAuthorization()
        case .authorizedAlways, .denied, .restricted:
            break
        @unknown default:
            break
        }
    }
    /// Cached coordinates are rounded to roughly one kilometre and expire after 12 hours.
    func usableLocation() async -> CLLocation? {
        if let cached = cachedLocation(), Date().timeIntervalSince(cached.timestamp) <= Self.cacheFreshness { return cached }
        guard manager.authorizationStatus == .authorizedAlways else { return nil }
        return await withCheckedContinuation { continuation in self.continuation = continuation; manager.requestLocation() }
    }
    func cachedLocationAgeText() -> String { guard let cached = cachedLocation() else { return "Bez cache" }; let hours = Int(Date().timeIntervalSince(cached.timestamp) / 3600); return hours == 0 ? "čerstvá" : "\(hours) h" }
    var managerAuthorizationText: String { switch manager.authorizationStatus { case .authorizedAlways: "Vždy povolené"; case .authorizedWhenInUse: "Len pri používaní"; case .denied: "Zamietnuté"; case .restricted: "Obmedzené"; default: "Neoverené" } }
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let location = locations.last
        Task { @MainActor [weak self] in
            self?.finishLocationRequest(with: location)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor [weak self] in
            self?.finishLocationRequest(with: nil)
        }
    }

    private func finishLocationRequest(with location: CLLocation?) {
        if let location {
            defaults.set((location.coordinate.latitude * 100).rounded() / 100, forKey: "WeatherLocation.latitude")
            defaults.set((location.coordinate.longitude * 100).rounded() / 100, forKey: "WeatherLocation.longitude")
            defaults.set(location.timestamp, forKey: "WeatherLocation.date")
        }
        continuation?.resume(returning: location)
        continuation = nil
    }
    private func cachedLocation() -> CLLocation? {
        guard let date = defaults.object(forKey: "WeatherLocation.date") as? Date else { return nil }
        return CLLocation(
            coordinate: CLLocationCoordinate2D(
                latitude: defaults.double(forKey: "WeatherLocation.latitude"),
                longitude: defaults.double(forKey: "WeatherLocation.longitude")
            ),
            altitude: 0,
            horizontalAccuracy: 1_000,
            verticalAccuracy: -1,
            timestamp: date
        )
    }
}
