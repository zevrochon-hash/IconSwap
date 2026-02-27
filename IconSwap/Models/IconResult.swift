import Foundation

struct IconResult: Identifiable, Hashable, Sendable {
    let id: String                  // objectID from API
    let appName: String
    let icnsUrl: URL                // ONLY this URL is used for replacement
    let lowResPngUrl: String        // thumbnail preview only — never used for replacement
    let creatorName: String         // usersName from API
    let creditUrl: URL?             // credit field from API (is a URL, e.g. twitter link)
    let downloads: Int
}

// MARK: - API Decodable types

struct IconSearchResponse: Decodable {
    let hits: [IconHit]
    let query: String
    let totalHits: Int
    let hitsPerPage: Int
    let page: Int
    let totalPages: Int
    let processingTimeMs: Int?
}

struct IconHit: Decodable {
    let objectID: String
    let appName: String
    let lowResPngUrl: String
    let icnsUrl: String
    let iOSUrl: String?             // decoded but never used
    let category: String?
    let usersName: String?          // creator's display name
    let credit: String?             // creator's URL (e.g. twitter profile)
    let uploadedBy: String?         // uploader profile URL
    let downloads: Int?
    let timeStamp: Int?

    func toIconResult() -> IconResult? {
        guard let icnsURL = URL(string: icnsUrl) else { return nil }
        return IconResult(
            id: objectID,
            appName: appName,
            icnsUrl: icnsURL,
            lowResPngUrl: lowResPngUrl,
            creatorName: usersName ?? "",
            creditUrl: credit.flatMap { URL(string: $0) },
            downloads: downloads ?? 0
        )
    }
}
