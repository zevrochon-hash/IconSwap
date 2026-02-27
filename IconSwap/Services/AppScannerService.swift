import AppKit
import Foundation

@MainActor
final class AppScannerService: ObservableObject {

    private let scanPaths: [URL] = [
        URL(fileURLWithPath: "/Applications"),
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications")
    ]

    func scanInstalledApps() async throws -> [InstalledApp] {
        let dockBundleIDs = fetchDockBundleIdentifiers()
        var apps: [InstalledApp] = []

        for basePath in scanPaths {
            guard FileManager.default.fileExists(atPath: basePath.path) else { continue }

            let contents: [URL]
            do {
                contents = try FileManager.default.contentsOfDirectory(
                    at: basePath,
                    includingPropertiesForKeys: [.contentModificationDateKey],
                    options: [.skipsHiddenFiles]
                )
            } catch {
                AppLogger.scanner.warning("Could not scan \(basePath.path): \(error)")
                continue
            }

            for url in contents where url.pathExtension == "app" {
                if let app = buildInstalledApp(from: url, dockIDs: dockBundleIDs) {
                    apps.append(app)
                }
            }
        }

        return apps.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
    }

    // MARK: - Private

    private func buildInstalledApp(from url: URL, dockIDs: Set<String>) -> InstalledApp? {
        let plistURL = url.appendingPathComponent("Contents/Info.plist")
        guard
            let plist = NSDictionary(contentsOf: plistURL),
            let bundleID = plist["CFBundleIdentifier"] as? String
        else { return nil }

        let name = (plist["CFBundleDisplayName"] as? String)
                ?? (plist["CFBundleName"] as? String)
                ?? url.deletingPathExtension().lastPathComponent

        var iconFileName = (plist["CFBundleIconFile"] as? String) ?? "AppIcon"
        if !iconFileName.hasSuffix(".icns") {
            iconFileName += ".icns"
        }

        let iconURL = url
            .appendingPathComponent("Contents/Resources")
            .appendingPathComponent(iconFileName)

        let modDate = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))
            .flatMap(\.contentModificationDate) ?? Date.distantPast

        let version = (plist["CFBundleShortVersionString"] as? String) ?? "0"
        let hasCustom = detectCustomIcon(at: url)
        let isLegacy = detectLegacyIcon(at: iconURL)

        return InstalledApp(
            id: bundleID,
            name: name,
            bundleURL: url,
            bundleIdentifier: bundleID,
            version: version,
            iconFileName: iconFileName,
            iconURL: iconURL,
            hasCustomIcon: hasCustom,
            isInDock: dockIDs.contains(bundleID),
            isLegacyIcon: isLegacy,
            modificationDate: modDate
        )
    }

    /// Check the com.apple.FinderInfo extended attribute custom icon bit (byte 8, bit 2).
    private func detectCustomIcon(at url: URL) -> Bool {
        url.withUnsafeFileSystemRepresentation { path -> Bool in
            guard let path else { return false }
            let bufLen = getxattr(path, "com.apple.FinderInfo", nil, 0, 0, XATTR_NOFOLLOW)
            guard bufLen >= 10 else { return false }
            var buf = [UInt8](repeating: 0, count: bufLen)
            let result = getxattr(path, "com.apple.FinderInfo", &buf, bufLen, 0, XATTR_NOFOLLOW)
            guard result >= 10 else { return false }
            return (buf[8] & 0x04) != 0
        }
    }

    /// Icon is "legacy" if the .icns has no representation >= 512x512.
    private func detectLegacyIcon(at iconURL: URL) -> Bool {
        guard FileManager.default.fileExists(atPath: iconURL.path),
              let image = NSImage(contentsOf: iconURL) else { return true }
        return !image.representations.contains {
            $0.pixelsWide >= 512 && $0.pixelsHigh >= 512
        }
    }

    /// Read persistent Dock apps from com.apple.dock preferences.
    private func fetchDockBundleIdentifiers() -> Set<String> {
        guard
            let dockPrefs = UserDefaults(suiteName: "com.apple.dock"),
            let persistentApps = dockPrefs.array(forKey: "persistent-apps") as? [[String: Any]]
        else { return [] }

        return Set(persistentApps.compactMap { entry -> String? in
            (entry["tile-data"] as? [String: Any])?["bundle-identifier"] as? String
        })
    }
}
