import SwiftUI

@MainActor
final class SettingsViewModel: ObservableObject {
    // Intentionally thin — settings are read directly via @AppStorage in views.
    // This class exists as a hook for future validation logic.

    @AppStorage("macosIconsApiKey") var apiKey: String = ""
    @AppStorage("autoReapplyOnUpdate") var autoReapplyOnUpdate: Bool = true
    @AppStorage("showLegacyWarnings") var showLegacyWarnings: Bool = true
}
