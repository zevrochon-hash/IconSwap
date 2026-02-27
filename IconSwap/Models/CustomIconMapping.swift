import Foundation

struct CustomIconMapping: Identifiable, Sendable {
    let id: UUID
    let bundleIdentifier: String
    let appName: String
    let appBundleURL: String            // snapshot of path at time of replacement
    let iconObjectID: String            // IconResult.id (the icnsUrl)
    let icnsUrl: String                 // remote URL for re-download if needed
    let localIcnsPath: String           // path to cached .icns on disk
    let appliedDate: Date
    var lastVerifiedDate: Date?
    var appVersionAtApplication: String
}
