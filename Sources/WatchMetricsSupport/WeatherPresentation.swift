public enum WeatherConditionKind: Sendable {
    case clear
    case cloudy
    case rain
    case thunderstorm
    case snow
    case fog
}

public struct WeatherPresentation: Equatable, Sendable {
    public let emoji: String
    public let symbolName: String
    public let text: String

    public init(emoji: String, symbolName: String, text: String) {
        self.emoji = emoji
        self.symbolName = symbolName
        self.text = text
    }
}

public enum WeatherPresentationMapper {
    public static func presentation(for kind: WeatherConditionKind) -> WeatherPresentation {
        switch kind {
        case .clear:
            WeatherPresentation(emoji: "☀️", symbolName: "sun.max.fill", text: "jasno")
        case .cloudy:
            WeatherPresentation(emoji: "☁️", symbolName: "cloud.fill", text: "oblačno")
        case .rain:
            WeatherPresentation(emoji: "🌧️", symbolName: "cloud.rain.fill", text: "dážď")
        case .thunderstorm:
            WeatherPresentation(emoji: "⛈️", symbolName: "cloud.bolt.rain.fill", text: "búrka")
        case .snow:
            WeatherPresentation(emoji: "❄️", symbolName: "snowflake", text: "sneženie")
        case .fog:
            WeatherPresentation(emoji: "🌫️", symbolName: "cloud.fog.fill", text: "hmla")
        }
    }
}
