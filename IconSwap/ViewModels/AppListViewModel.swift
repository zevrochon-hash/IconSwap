import SwiftUI
import Combine

@MainActor
final class AppListViewModel: ObservableObject {

    @Published var filteredApps: [InstalledApp] = []
    @Published var searchQuery: String = ""
    @Published var selectedFilter: AppFilter = .all
    @Published var selectedApp: InstalledApp?
    @Published var isScanning: Bool = false
    @Published var errorMessage: String?
    @Published var customizedBundleIDs: Set<String> = []

    private var allApps: [InstalledApp] = []
    private let scanner: AppScannerService
    private let persistence: PersistenceService
    private var cancellables = Set<AnyCancellable>()

    init(scanner: AppScannerService, persistence: PersistenceService) {
        self.scanner = scanner
        self.persistence = persistence
        observeFilters()
    }

    // MARK: - Public

    func scanApps() async {
        isScanning = true
        errorMessage = nil
        do {
            allApps = try await scanner.scanInstalledApps()
            refreshCustomizedSet()
            applyFilter()
        } catch {
            errorMessage = error.localizedDescription
        }
        isScanning = false
    }

    func refreshCustomizedSet() {
        let mappings = persistence.fetchAllMappings()
        customizedBundleIDs = Set(mappings.map { $0.bundleIdentifier })
    }

    // MARK: - Private

    private func observeFilters() {
        Publishers.CombineLatest($searchQuery, $selectedFilter)
            .debounce(for: .milliseconds(150), scheduler: RunLoop.main)
            .sink { [weak self] _, _ in self?.applyFilter() }
            .store(in: &cancellables)
    }

    private func applyFilter() {
        var result = allApps

        if !searchQuery.isEmpty {
            result = result.filter {
                $0.name.localizedCaseInsensitiveContains(searchQuery)
            }
        }

        switch selectedFilter {
        case .all:
            break
        case .dockOnly:
            result = result.filter { $0.isInDock }
        case .legacyIcons:
            result = result.filter { $0.isLegacyIcon }
        case .customized:
            result = result.filter { customizedBundleIDs.contains($0.bundleIdentifier) }
        }

        filteredApps = result
    }
}
