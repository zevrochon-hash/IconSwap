import Foundation

actor IconReplacementService {

    private let fileiconPath: String

    init() {
        self.fileiconPath = FileiconInstaller.findInstalledPath() ?? "/opt/homebrew/bin/fileicon"
    }

    // MARK: - Apply

    /// Apply a custom .icns to an app bundle.
    /// Tries direct execution first (no password prompt for user-owned apps).
    /// Falls back to privileged osascript only if permission is denied.
    func applyIcon(app: InstalledApp, icnsPath: URL) async throws {
        AppLogger.replace.info("Applying icon to \(app.name): \(icnsPath.path)")

        let appPath = app.bundleURL.path
        let iconPath = icnsPath.path

        // Try direct first — works for apps installed by the current user
        let direct = try await Process.run(
            executable: fileiconPath,
            arguments: ["set", appPath, iconPath]
        )

        if direct.exitCode != 0 {
            AppLogger.replace.warning("Direct fileicon failed, retrying with admin privileges")
            // osascript runs in a clean environment; pass the full path to fileicon
            let cmd = "\(shellEscape(fileiconPath)) set \(shellEscape(appPath)) \(shellEscape(iconPath))"
            let privileged = try await Process.runPrivileged(shellCommand: cmd)
            if privileged.exitCode != 0 {
                let msg = extractFileiconError(from: privileged.stderr)
                AppLogger.replace.error("fileicon set failed (privileged): \(msg)")
                throw IconReplacementError.fileiconFailed(msg)
            }
        }

        // Touch bundle to invalidate Dock/Launchpad icon cache
        _ = try? await Process.run(executable: "/usr/bin/touch", arguments: [appPath])
        await restartDock()
        AppLogger.replace.info("Icon applied to \(app.name)")
    }

    // MARK: - Restore

    /// Remove custom icon from an app bundle, reverting to its original.
    func restoreIcon(app: InstalledApp) async throws {
        AppLogger.replace.info("Restoring icon for \(app.name)")

        let appPath = app.bundleURL.path

        let direct = try await Process.run(
            executable: fileiconPath,
            arguments: ["rm", appPath]
        )

        if direct.exitCode != 0 {
            AppLogger.replace.warning("Direct fileicon rm failed, retrying with admin privileges")
            let cmd = "\(shellEscape(fileiconPath)) rm \(shellEscape(appPath))"
            let privileged = try await Process.runPrivileged(shellCommand: cmd)
            if privileged.exitCode != 0 {
                let msg = extractFileiconError(from: privileged.stderr)
                AppLogger.replace.error("fileicon rm failed (privileged): \(msg)")
                throw IconReplacementError.fileiconFailed(msg)
            }
        }

        _ = try? await Process.run(executable: "/usr/bin/touch", arguments: [appPath])
        await restartDock()
        AppLogger.replace.info("Icon restored for \(app.name)")
    }

    // MARK: - Helpers

    private func restartDock() async {
        _ = try? await Process.run(executable: "/usr/bin/killall", arguments: ["Dock"])
    }

    /// Shell-escape a path by wrapping in single quotes and escaping any embedded single quotes.
    private func shellEscape(_ s: String) -> String {
        "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    /// Extract the human-readable fileicon error from an osascript stderr string.
    /// osascript wraps errors as: "N:M: execution error: <message> (exitcode)"
    private func extractFileiconError(from osascriptStderr: String) -> String {
        let raw = osascriptStderr.trimmingCharacters(in: .whitespacesAndNewlines)
        // Try to extract the inner message between "execution error: " and " (N)"
        if let errorRange = raw.range(of: "execution error: ") {
            var msg = String(raw[errorRange.upperBound...])
            // Strip trailing " (exitcode)"
            if let parenRange = msg.range(of: " (", options: .backwards) {
                msg = String(msg[..<parenRange.lowerBound])
            }
            return msg.isEmpty ? raw : msg
        }
        return raw.isEmpty ? "fileicon failed with no output." : raw
    }
}

// MARK: - Errors

enum IconReplacementError: LocalizedError {
    case fileiconNotInstalled
    case fileiconFailed(String)

    var errorDescription: String? {
        switch self {
        case .fileiconNotInstalled:
            return "fileicon is not installed. Run: brew install fileicon"
        case .fileiconFailed(let msg):
            return msg.isEmpty ? "fileicon failed." : msg
        }
    }
}
