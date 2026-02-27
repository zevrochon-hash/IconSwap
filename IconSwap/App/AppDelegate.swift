import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {

    private var updateMonitor: AppUpdateMonitor?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let monitor = AppUpdateMonitor(
            persistence: PersistenceService.shared,
            replacement: IconReplacementService()
        )
        self.updateMonitor = monitor
        monitor.startMonitoring()
    }

    func applicationWillTerminate(_ notification: Notification) {
        updateMonitor?.stopMonitoring()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false   // Stay running in background for update monitoring
    }
}
