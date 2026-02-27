import OSLog

enum AppLogger {
    static let scanner  = Logger(subsystem: "com.iconswap", category: "scanner")
    static let api      = Logger(subsystem: "com.iconswap", category: "api")
    static let download = Logger(subsystem: "com.iconswap", category: "download")
    static let replace  = Logger(subsystem: "com.iconswap", category: "replace")
    static let monitor  = Logger(subsystem: "com.iconswap", category: "monitor")
    static let persist  = Logger(subsystem: "com.iconswap", category: "persist")
}
