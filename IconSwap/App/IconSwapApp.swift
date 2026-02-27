import SwiftUI

@main
struct IconSwapApp: App {

    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    // Shared service instances
    private let persistence   = PersistenceService.shared
    private let scanner       = AppScannerService()
    private let apiService    = IconAPIService()
    private let replacement   = IconReplacementService()
    private let downloadService: IconDownloadService

    init() {
        // IconDownloadService throws only if Application Support is inaccessible,
        // which is unrecoverable — crash with a meaningful message.
        do {
            downloadService = try IconDownloadService()
        } catch {
            fatalError("Could not create icon download cache: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            MainWindowView()
                .environmentObject(
                    AppListViewModel(scanner: scanner, persistence: persistence)
                )
                .environmentObject(
                    IconGridViewModel(
                        apiService: apiService,
                        downloadService: downloadService,
                        replacementService: replacement,
                        persistence: persistence
                    )
                )
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: true))
        .defaultSize(width: 1100, height: 700)

        Settings {
            SettingsView()
        }
    }
}
