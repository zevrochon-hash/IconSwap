import Foundation

enum AppFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case dockOnly = "Dock"
    case legacyIcons = "Legacy"
    case customized = "Customized"

    var id: String { rawValue }
}
