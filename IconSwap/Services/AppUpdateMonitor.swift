import Foundation

final class AppUpdateMonitor: @unchecked Sendable {

    private let persistence: PersistenceService
    private let replacement: IconReplacementService
    private var eventStream: FSEventStreamRef?
    private var pollTimer: Timer?
    private var knownModDates: [String: Date] = [:]     // appBundleURL -> modDate

    init(persistence: PersistenceService, replacement: IconReplacementService) {
        self.persistence = persistence
        self.replacement = replacement
    }

    // MARK: - Lifecycle

    func startMonitoring() {
        let mappings = persistence.fetchAllMappings()
        guard !mappings.isEmpty else {
            AppLogger.monitor.info("No mappings to monitor.")
            return
        }

        // Snapshot initial mod dates
        for mapping in mappings {
            let url = URL(fileURLWithPath: mapping.appBundleURL)
            knownModDates[mapping.appBundleURL] =
                (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
        }

        let watchedPaths = mappings.map { $0.appBundleURL } as CFArray
        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil, release: nil, copyDescription: nil
        )

        eventStream = FSEventStreamCreate(
            nil,
            { _, clientInfo, numEvents, eventPaths, _, _ in
                let monitor = Unmanaged<AppUpdateMonitor>
                    .fromOpaque(clientInfo!).takeUnretainedValue()
                let rawPaths = unsafeBitCast(eventPaths, to: UnsafeMutablePointer<UnsafePointer<CChar>?>.self)
                var paths: [String] = []
                for i in 0..<numEvents {
                    if let p = rawPaths[i] {
                        paths.append(String(cString: p))
                    }
                }
                Task { await monitor.handleFSEvents(paths: paths) }
            },
            &context,
            watchedPaths,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            2.0,
            FSEventStreamCreateFlags(kFSEventStreamCreateFlagNone)
        )

        if let stream = eventStream {
            FSEventStreamSetDispatchQueue(stream, DispatchQueue.main)
            FSEventStreamStart(stream)
            AppLogger.monitor.info("FSEvents monitoring \(mappings.count) app(s)")
        }

        // Fallback poll every 30 minutes
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1800, repeats: true) { [weak self] _ in
            Task { await self?.pollForUpdates() }
        }
    }

    func stopMonitoring() {
        if let stream = eventStream {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
            eventStream = nil
        }
        pollTimer?.invalidate()
        pollTimer = nil
        AppLogger.monitor.info("Monitoring stopped")
    }

    // MARK: - Private

    private func handleFSEvents(paths: [String]) async {
        for path in paths {
            let appPath = extractAppBundlePath(from: path)
            await reapplyIconIfUpdated(for: appPath)
        }
    }

    private func pollForUpdates() async {
        let mappings = persistence.fetchAllMappings()
        for mapping in mappings {
            await reapplyIconIfUpdated(for: mapping.appBundleURL)
        }
    }

    private func reapplyIconIfUpdated(for appBundlePath: String) async {
        let url = URL(fileURLWithPath: appBundlePath)
        guard let currentMod = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate else { return }

        let lastKnown = knownModDates[appBundlePath]
        if let lastKnown, currentMod <= lastKnown { return }

        // App was updated — reapply icon
        knownModDates[appBundlePath] = currentMod

        guard let mapping = persistence.fetchAllMappings().first(where: { $0.appBundleURL == appBundlePath }) else { return }
        let icnsURL = URL(fileURLWithPath: mapping.localIcnsPath)
        guard FileManager.default.fileExists(atPath: icnsURL.path) else {
            AppLogger.monitor.warning("Cached icns missing for \(mapping.appName), skipping reapply")
            return
        }

        AppLogger.monitor.info("App update detected for \(mapping.appName), reapplying icon")
        let app = InstalledApp(
            id: mapping.bundleIdentifier,
            name: mapping.appName,
            bundleURL: url,
            bundleIdentifier: mapping.bundleIdentifier,
            version: mapping.appVersionAtApplication,
            iconFileName: "AppIcon.icns",
            iconURL: url,
            hasCustomIcon: false,
            isInDock: false,
            isLegacyIcon: false,
            modificationDate: currentMod
        )

        do {
            try await replacement.applyIcon(app: app, icnsPath: icnsURL)
            persistence.updateVerifiedDate(bundleIdentifier: mapping.bundleIdentifier, date: Date())
        } catch {
            AppLogger.monitor.error("Failed to reapply icon for \(mapping.appName): \(error)")
        }
    }

    private func extractAppBundlePath(from path: String) -> String {
        // Find the .app boundary in a possibly deeper path
        if let range = path.range(of: #"[^/]+\.app"#, options: .regularExpression) {
            let end = path.index(range.upperBound, offsetBy: 0)
            return String(path[..<end])
        }
        return path
    }
}

