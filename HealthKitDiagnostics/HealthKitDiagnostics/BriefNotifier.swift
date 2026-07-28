import Foundation
import MetricsCore
import UserNotifications

/// Delivers a composed `BriefContent` as a local notification. Thin shell
/// wrapper — all the text it sends comes straight from `BriefRenderer`, no
/// formatting logic lives here.
///
/// `@MainActor` so calling it from `BriefRunner` (also `@MainActor`) is a
/// same-actor call, not a cross-isolation one — otherwise Swift 6's
/// region-based Sendable checking flags `notify(_:)`'s `BriefContent`
/// argument, since `BriefContent` (defined in MetricsCore) isn't declared
/// explicitly `Sendable`.
@MainActor
struct BriefNotifier {
    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    func requestAuthorization() async throws {
        let granted = try await center.requestAuthorization(options: [.alert, .sound])
        guard granted else { throw BriefNotifierError.authorizationDenied }
    }

    func notify(_ content: BriefContent) async throws {
        try await ensureAuthorized()
        let notificationContent = UNMutableNotificationContent()
        notificationContent.title = content.title
        notificationContent.body = BriefRenderer.renderLines(content.lines)
        notificationContent.sound = .default

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: notificationContent, trigger: nil)
        try await center.add(request)
    }

    private func ensureAuthorized() async throws {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional:
            return
        case .notDetermined, .denied:
            throw BriefNotifierError.authorizationDenied
        @unknown default:
            throw BriefNotifierError.authorizationDenied
        }
    }
}

enum BriefNotifierError: LocalizedError {
    case authorizationDenied

    var errorDescription: String? {
        "Notifikácie nie sú povolené"
    }
}
