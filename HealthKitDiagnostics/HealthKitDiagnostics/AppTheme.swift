import SwiftUI

/// Shared visual language across the metric-overview screens, drawn from
/// the app icon's indigo -> teal EKG motif (Assets.xcassets/AppIcon.appiconset)
/// instead of default system colors.
enum AppTheme {
    /// Matches the app icon's dark indigo top.
    static let background = Color(red: 0.04, green: 0.06, blue: 0.16)
    /// Matches the app icon's teal bottom / pulse-line accent.
    static let accent = Color(red: 0.0, green: 0.76, blue: 0.66)
    /// A lighter indigo for card surfaces, so cards read as distinct from
    /// the screen background without breaking from the icon's palette.
    static let cardBackground = Color(red: 0.10, green: 0.13, blue: 0.30)
    static let elevatedBackground = Color(red: 0.14, green: 0.18, blue: 0.38)
    static let secondaryText = Color.white.opacity(0.68)

    // Immersive Today dashboard palette. These remain presentation-only;
    // status semantics still come exclusively from MetricsCore.
    static let dashboardBackground = Color(red: 0.012, green: 0.018, blue: 0.055)
    static let dashboardSurface = Color(red: 0.055, green: 0.072, blue: 0.145)
    static let dashboardBlue = Color(red: 0.18, green: 0.52, blue: 1.00)
    static let dashboardCyan = Color(red: 0.10, green: 0.90, blue: 0.96)
    static let dashboardGreen = Color(red: 0.18, green: 0.92, blue: 0.58)
    static let dashboardViolet = Color(red: 0.59, green: 0.34, blue: 1.00)
    static let dashboardAmber = Color(red: 1.00, green: 0.66, blue: 0.20)
    static let dashboardMagenta = Color(red: 1.00, green: 0.20, blue: 0.66)
    static let dashboardRed = Color(red: 1.00, green: 0.24, blue: 0.30)

    /// Traffic-light status colors. Deliberately vivid/high-contrast for
    /// small-display, bright-sunlight readability, and deliberately NOT
    /// derived from the indigo/teal brand palette — green/yellow/red carry
    /// universal meaning here and shouldn't be reinterpreted for branding.
    static let statusNormal = Color(red: 0.20, green: 0.85, blue: 0.40)
    static let statusLow = Color(red: 1.00, green: 0.80, blue: 0.00)
    static let statusCritical = Color(red: 1.00, green: 0.23, blue: 0.19)

    static let cardCornerRadius: CGFloat = 16
    static let spacing: CGFloat = 10
    static let cardPadding: CGFloat = 12
}
