import SwiftUI

@MainActor
final class IconGridViewModel: ObservableObject {

    @Published var icons: [IconResult] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var currentPage: Int = 1
    @Published var totalPages: Int = 1
    @Published var appliedIconID: String?       // shows checkmark overlay

    private let apiService: IconAPIService
    private let downloadService: IconDownloadService
    private let replacementService: IconReplacementService
    private let persistence: PersistenceService

    @AppStorage("macosIconsApiKey") private var apiKey: String = ""

    var selectedApp: InstalledApp? {
        didSet {
            guard selectedApp?.id != oldValue?.id else { return }
            icons = []
            currentPage = 1
            totalPages = 1
            // Restore current applied icon indicator
            if let app = selectedApp {
                appliedIconID = persistence.fetchMapping(for: app.bundleIdentifier)?.iconObjectID
            } else {
                appliedIconID = nil
            }
            if selectedApp != nil {
                Task { await searchIcons() }
            }
        }
    }

    init(
        apiService: IconAPIService,
        downloadService: IconDownloadService,
        replacementService: IconReplacementService,
        persistence: PersistenceService
    ) {
        self.apiService = apiService
        self.downloadService = downloadService
        self.replacementService = replacementService
        self.persistence = persistence
    }

    // MARK: - Search

    func searchIcons(page: Int = 1) async {
        guard let app = selectedApp else { return }
        isLoading = true
        errorMessage = nil

        do {
            let response = try await apiService.searchIcons(
                for: app.name,
                page: page,
                apiKey: apiKey
            )
            let newIcons = response.hits.compactMap { $0.toIconResult() }

            if page == 1 {
                icons = newIcons
            } else {
                icons += newIcons
            }

            currentPage = response.page
            totalPages = response.totalPages
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func loadNextPage() async {
        guard currentPage < totalPages, !isLoading else { return }
        await searchIcons(page: currentPage + 1)
    }

    // MARK: - Apply / Restore

    func applyIcon(_ icon: IconResult, toApp app: InstalledApp) async {
        isLoading = true
        errorMessage = nil
        do {
            let localPath = try await downloadService.download(icon: icon)
            try await replacementService.applyIcon(app: app, icnsPath: localPath)

            let mapping = CustomIconMapping(
                id: UUID(),
                bundleIdentifier: app.bundleIdentifier,
                appName: app.name,
                appBundleURL: app.bundleURL.path,
                iconObjectID: icon.id,
                icnsUrl: icon.icnsUrl.absoluteString,
                localIcnsPath: localPath.path,
                appliedDate: Date(),
                lastVerifiedDate: nil,
                appVersionAtApplication: app.version
            )
            persistence.saveMapping(mapping)
            appliedIconID = icon.id
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func restoreIcon(for app: InstalledApp) async {
        isLoading = true
        errorMessage = nil
        do {
            try await replacementService.restoreIcon(app: app)
            persistence.deleteMapping(bundleIdentifier: app.bundleIdentifier)
            appliedIconID = nil
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func importCustomIcon(from fileURL: URL, for app: InstalledApp) async {
        isLoading = true
        errorMessage = nil
        do {
            try await replacementService.applyIcon(app: app, icnsPath: fileURL)
            let mapping = CustomIconMapping(
                id: UUID(),
                bundleIdentifier: app.bundleIdentifier,
                appName: app.name,
                appBundleURL: app.bundleURL.path,
                iconObjectID: "custom:\(fileURL.lastPathComponent)",
                icnsUrl: fileURL.absoluteString,
                localIcnsPath: fileURL.path,
                appliedDate: Date(),
                lastVerifiedDate: nil,
                appVersionAtApplication: app.version
            )
            persistence.saveMapping(mapping)
            appliedIconID = mapping.iconObjectID
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
