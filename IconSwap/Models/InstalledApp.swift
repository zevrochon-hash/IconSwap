import Foundation
import AppKit

struct InstalledApp: Identifiable, Hashable, Sendable {
    let id: String                      // bundleIdentifier
    let name: String
    let bundleURL: URL
    let bundleIdentifier: String
    let version: String
    let iconFileName: String            // CFBundleIconFile value
    let iconURL: URL                    // full path to .icns inside bundle
    var hasCustomIcon: Bool             // com.apple.FinderInfo xattr custom icon bit
    var isInDock: Bool
    var isLegacyIcon: Bool              // no 512x512+ representation
    var modificationDate: Date

    static func == (lhs: InstalledApp, rhs: InstalledApp) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
