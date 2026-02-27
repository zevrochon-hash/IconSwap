import Foundation

struct ProcessResult {
    let exitCode: Int32
    let stdout: String
    let stderr: String
}

extension Process {

    static func run(
        executable: String,
        arguments: [String],
        environment: [String: String]? = nil
    ) async throws -> ProcessResult {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = arguments
            process.environment = environment ?? ProcessInfo.processInfo.environment

            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe

            process.terminationHandler = { p in
                let out = String(
                    data: stdoutPipe.fileHandleForReading.readDataToEndOfFile(),
                    encoding: .utf8
                ) ?? ""
                let err = String(
                    data: stderrPipe.fileHandleForReading.readDataToEndOfFile(),
                    encoding: .utf8
                ) ?? ""
                continuation.resume(returning: ProcessResult(
                    exitCode: p.terminationStatus,
                    stdout: out,
                    stderr: err
                ))
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    /// Run a shell command with administrator privileges via osascript.
    /// Shows the macOS password prompt if needed.
    static func runPrivileged(shellCommand: String) async throws -> ProcessResult {
        let escaped = shellCommand.replacingOccurrences(of: "\"", with: "\\\"")
        let script = "do shell script \"\(escaped)\" with administrator privileges"
        return try await run(
            executable: "/usr/bin/osascript",
            arguments: ["-e", script]
        )
    }
}
