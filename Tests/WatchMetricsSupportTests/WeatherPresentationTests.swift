import Testing
@testable import WatchMetricsSupport

struct WeatherPresentationTests {
    @Test(arguments: [
        (WeatherConditionKind.clear, "☀️", "sun.max.fill", "jasno"),
        (WeatherConditionKind.cloudy, "☁️", "cloud.fill", "oblačno"),
        (WeatherConditionKind.rain, "🌧️", "cloud.rain.fill", "dážď"),
        (WeatherConditionKind.thunderstorm, "⛈️", "cloud.bolt.rain.fill", "búrka"),
        (WeatherConditionKind.snow, "❄️", "snowflake", "sneženie"),
        (WeatherConditionKind.fog, "🌫️", "cloud.fog.fill", "hmla")
    ])
    func presentsBasicConditions(
        kind: WeatherConditionKind,
        emoji: String,
        symbolName: String,
        text: String
    ) {
        let presentation = WeatherPresentationMapper.presentation(for: kind)

        #expect(presentation.emoji == emoji)
        #expect(presentation.symbolName == symbolName)
        #expect(presentation.text == text)
    }
}
