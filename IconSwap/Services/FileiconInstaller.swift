import Foundation

enum FileiconInstaller {

    static let expectedPaths: [String] = [
        "/opt/homebrew/bin/fileicon",   // Apple Silicon Homebrew
        "/usr/local/bin/fileicon"        // Intel Mac Homebrew
    ]

    static func findInstalledPath() -> String? {
        expectedPaths.first { FileManager.default.fileExists(atPath: $0) }
    }

    static var isInstalled: Bool {
        findInstalledPath() != nil
    }

    static var installCommand: String {
        "brew install fileicon"
    }

    static var installationInstructions: String {
        """
        fileicon is required to replace app icons.

        Install it with Homebrew:
            brew install fileicon

        Then restart IconSwap.
        """
    }
}
