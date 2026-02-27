import Foundation

actor IconAPIService {

    private let endpoint = URL(string: "https://api.macosicons.com/api/v1/search")!
    private let session: URLSession

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.waitsForConnectivity = true
        session = URLSession(configuration: config)
    }

    /// Search macosicons.com for icons matching appName.
    /// - Parameters:
    ///   - appName: App name to search for.
    ///   - page: 1-based page number.
    ///   - apiKey: macosicons.com API key from Settings.
    func searchIcons(
        for appName: String,
        page: Int = 1,
        apiKey: String
    ) async throws -> IconSearchResponse {
        guard !apiKey.isEmpty else {
            throw IconAPIError.missingAPIKey
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")

        let body: [String: Any] = [
            "query": appName,
            "searchOptions": [
                "hitsPerPage": 20,
                "page": page
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        AppLogger.api.debug("Searching icons for '\(appName)' page=\(page)")

        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw IconAPIError.invalidResponse
        }

        switch http.statusCode {
        case 200:
            do {
                let decoded = try JSONDecoder().decode(IconSearchResponse.self, from: data)
                AppLogger.api.debug("Got \(decoded.hits.count) hits (page \(decoded.page)/\(decoded.totalPages), totalHits=\(decoded.totalHits))")
                return decoded
            } catch {
                AppLogger.api.error("Decode error: \(error)")
                throw IconAPIError.decodeFailed(error)
            }
        case 401:
            throw IconAPIError.unauthorized
        case 429:
            throw IconAPIError.rateLimitExceeded
        default:
            throw IconAPIError.httpError(http.statusCode)
        }
    }
}

// MARK: - Errors

enum IconAPIError: LocalizedError {
    case missingAPIKey
    case unauthorized
    case rateLimitExceeded
    case invalidResponse
    case decodeFailed(Error)
    case httpError(Int)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "No API key configured. Add your macosicons.com API key in Settings."
        case .unauthorized:
            return "Invalid API key. Check Settings → API Key."
        case .rateLimitExceeded:
            return "API rate limit reached (50 requests/month on free tier)."
        case .invalidResponse:
            return "Unexpected response from macosicons.com."
        case .decodeFailed(let e):
            return "Failed to parse API response: \(e.localizedDescription)"
        case .httpError(let code):
            return "Server error: HTTP \(code)."
        }
    }
}
