import Foundation
import SQLite3

final class PersistenceService: @unchecked Sendable {

    static let shared = PersistenceService()

    private var db: OpaquePointer?
    private let queue = DispatchQueue(label: "com.iconswap.db", qos: .utility)

    private init() {
        let path = dbPath()
        AppLogger.persist.info("SQLite path: \(path)")
        sqlite3_open(path, &db)
        createTable()
    }

    deinit {
        sqlite3_close(db)
    }

    // MARK: - Schema

    private func createTable() {
        let sql = """
        CREATE TABLE IF NOT EXISTS icon_mappings (
            id                      TEXT PRIMARY KEY,
            bundle_identifier       TEXT NOT NULL UNIQUE,
            app_name                TEXT NOT NULL,
            app_bundle_url          TEXT NOT NULL,
            icon_object_id          TEXT NOT NULL,
            icns_url                TEXT NOT NULL,
            local_icns_path         TEXT NOT NULL,
            applied_date            REAL NOT NULL,
            last_verified_date      REAL,
            app_version             TEXT NOT NULL
        );
        """
        queue.sync { sqlite3_exec(db, sql, nil, nil, nil) }
    }

    // MARK: - CRUD

    func saveMapping(_ mapping: CustomIconMapping) {
        queue.async { [weak self] in
            guard let self else { return }
            let sql = """
            INSERT OR REPLACE INTO icon_mappings
            (id, bundle_identifier, app_name, app_bundle_url,
             icon_object_id, icns_url, local_icns_path,
             applied_date, last_verified_date, app_version)
            VALUES (?,?,?,?,?,?,?,?,?,?);
            """
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
            defer { sqlite3_finalize(stmt) }

            sqlite3_bind_text(stmt, 1,  mapping.id.uuidString,              -1, Self.transient)
            sqlite3_bind_text(stmt, 2,  mapping.bundleIdentifier,           -1, Self.transient)
            sqlite3_bind_text(stmt, 3,  mapping.appName,                    -1, Self.transient)
            sqlite3_bind_text(stmt, 4,  mapping.appBundleURL,               -1, Self.transient)
            sqlite3_bind_text(stmt, 5,  mapping.iconObjectID,               -1, Self.transient)
            sqlite3_bind_text(stmt, 6,  mapping.icnsUrl,                    -1, Self.transient)
            sqlite3_bind_text(stmt, 7,  mapping.localIcnsPath,              -1, Self.transient)
            sqlite3_bind_double(stmt, 8, mapping.appliedDate.timeIntervalSince1970)
            sqlite3_bind_double(stmt, 9, mapping.lastVerifiedDate?.timeIntervalSince1970 ?? 0)
            sqlite3_bind_text(stmt, 10, mapping.appVersionAtApplication,    -1, Self.transient)

            sqlite3_step(stmt)
        }
    }

    func fetchAllMappings() -> [CustomIconMapping] {
        var results: [CustomIconMapping] = []
        queue.sync {
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, "SELECT * FROM icon_mappings;", -1, &stmt, nil) == SQLITE_OK else { return }
            defer { sqlite3_finalize(stmt) }

            while sqlite3_step(stmt) == SQLITE_ROW {
                let id       = UUID(uuidString: String(cString: sqlite3_column_text(stmt, 0))) ?? UUID()
                let bundleID = String(cString: sqlite3_column_text(stmt, 1))
                let appName  = String(cString: sqlite3_column_text(stmt, 2))
                let appURL   = String(cString: sqlite3_column_text(stmt, 3))
                let objID    = String(cString: sqlite3_column_text(stmt, 4))
                let icnsURL  = String(cString: sqlite3_column_text(stmt, 5))
                let localP   = String(cString: sqlite3_column_text(stmt, 6))
                let applied  = sqlite3_column_double(stmt, 7)
                let verified = sqlite3_column_double(stmt, 8)
                let version  = String(cString: sqlite3_column_text(stmt, 9))

                let mapping = CustomIconMapping(
                    id: id,
                    bundleIdentifier: bundleID,
                    appName: appName,
                    appBundleURL: appURL,
                    iconObjectID: objID,
                    icnsUrl: icnsURL,
                    localIcnsPath: localP,
                    appliedDate: Date(timeIntervalSince1970: applied),
                    lastVerifiedDate: verified > 0 ? Date(timeIntervalSince1970: verified) : nil,
                    appVersionAtApplication: version
                )
                results.append(mapping)
            }
        }
        return results
    }

    func fetchMapping(for bundleIdentifier: String) -> CustomIconMapping? {
        fetchAllMappings().first { $0.bundleIdentifier == bundleIdentifier }
    }

    func deleteMapping(bundleIdentifier: String) {
        queue.async { [weak self] in
            guard let self else { return }
            var stmt: OpaquePointer?
            let sql = "DELETE FROM icon_mappings WHERE bundle_identifier = ?;"
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
            defer { sqlite3_finalize(stmt) }
            sqlite3_bind_text(stmt, 1, bundleIdentifier, -1, Self.transient)
            sqlite3_step(stmt)
        }
    }

    func updateVerifiedDate(bundleIdentifier: String, date: Date) {
        queue.async { [weak self] in
            guard let self else { return }
            var stmt: OpaquePointer?
            let sql = "UPDATE icon_mappings SET last_verified_date = ? WHERE bundle_identifier = ?;"
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
            defer { sqlite3_finalize(stmt) }
            sqlite3_bind_double(stmt, 1, date.timeIntervalSince1970)
            sqlite3_bind_text(stmt, 2, bundleIdentifier, -1, Self.transient)
            sqlite3_step(stmt)
        }
    }

    // MARK: - Helpers

    private func dbPath() -> String {
        guard let appSupport = try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ) else { return "" }
        let dir = appSupport.appendingPathComponent("IconSwap")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("db.sqlite").path
    }

    private static let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
}
