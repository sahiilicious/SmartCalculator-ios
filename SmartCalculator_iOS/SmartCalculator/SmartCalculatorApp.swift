import SwiftUI

/// Application entry point.
///
/// The app shows `HomeView` (a grid of tools). The chosen appearance
/// (System / Light / Dark) is stored with `@AppStorage` so it survives restarts.
@main
struct SmartCalculatorApp: App {
    @AppStorage(SettingsKeys.appearance) private var appearanceRaw: String = AppearanceMode.system.rawValue

    var body: some Scene {
        WindowGroup {
            HomeView()
                .preferredColorScheme(AppearanceMode(rawValue: appearanceRaw)?.colorScheme)
        }
    }
}
