import Foundation

actor IconDownloadService {

    private let cacheDirectory: URL
    private var inFlight: [String: Task<URL, Error>] = [:]
    private let session: URLSession

    init() throws {
        let appSupport = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        cacheDirectory = appSupport
            .appendingPathComponent("IconSwap")
            .appendingPathComponent("IconCache")
        try FileManager.default.createDirectory(
            at: cacheDirectory,
            withIntermediateDirectories: true
        )

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        session = URLSession(configuration: config)
    }

    /// Download the .icns file for the given IconResult.
    /// Returns the local file URL (cached on disk).
    func download(icon: IconResult) async throws -> URL {
        // Derive a stable filename from the icnsUrl
        let fileName = stableFileName(for: icon.icnsUrl.absoluteString)
        let localURL = cacheDirectory.appendingPathComponent(fileName)

        // Return immediately if already cached
        if FileManager.default.fileExists(atPath: localURL.path) {
            AppLogger.download.debug("Cache hit: \(fileName)")
            return localURL
        }

        // Deduplicate concurrent downloads for same icon
        if let existing = inFlight[icon.id] {
            return try await existing.value
        }

        let task = Task<URL, Error> {
            AppLogger.download.debug("Downloading: \(icon.icnsUrl.absoluteString)")
            let (tmpURL, _) = try await session.download(from: icon.icnsUrl)
            try FileManager.default.moveItem(at: tmpURL, to: localURL)
            AppLogger.download.debug("Downloaded: \(fileName)")
            return localURL
        }

        inFlight[icon.id] = task
        defer { inFlight.removeValue(forKey: icon.id) }
        return try await task.value
    }

    func cachedPath(for iconID: String) -> URL? {
        let fileName = stableFileName(for: iconID)
        let url = cacheDirectory.appendingPathComponent(fileName)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    func clearCache() throws {
        let files = try FileManager.default.contentsOfDirectory(
            at: cacheDirectory,
            includingPropertiesForKeys: nil
        )
        for file in files {
            try FileManager.default.removeItem(at: file)
        }
        AppLogger.download.info("Cache cleared (\(files.count) files removed)")
    }

    // MARK: - Private

    private func stableFileName(for urlString: String) -> String {
        // Use a hash of the URL to create a stable, filesystem-safe filename
        let hash = abs(urlString.hashValue)
        return "\(hash).icns"
    }
}
