import SwiftUI

struct SettingsView: View {
    @AppStorage("macosIconsApiKey") private var apiKey: String = ""
    @AppStorage("autoReapplyOnUpdate") private var autoReapply: Bool = true
    @AppStorage("showLegacyWarnings") private var showLegacyWarnings: Bool = true

    var body: some View {
        Form {
            Section("macosicons.com API") {
                SecureField("API Key", text: $apiKey)
                    .textFieldStyle(.roundedBorder)
                Text("Get a free key (50 req/month) at macosicons.com. Paid tier unlocks 1,000 req/month.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Behaviour") {
                Toggle("Auto-reapply icons after app updates", isOn: $autoReapply)
                Toggle("Show warning badge for legacy (non-Retina) icons", isOn: $showLegacyWarnings)
            }

            Section("fileicon") {
                LabeledContent("Status") {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(FileiconInstaller.isInstalled ? Color.green : Color.red)
                            .frame(width: 8, height: 8)
                        Text(FileiconInstaller.isInstalled ? "Installed" : "Not installed")
                            .foregroundColor(FileiconInstaller.isInstalled ? .primary : .red)
                    }
                }
                if !FileiconInstaller.isInstalled {
                    LabeledContent("Install") {
                        Text(FileiconInstaller.installCommand)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                    }
                }
                if let path = FileiconInstaller.findInstalledPath() {
                    LabeledContent("Path") {
                        Text(path)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 460, height: 340)
        .padding()
    }
}
