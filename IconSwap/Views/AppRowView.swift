import SwiftUI

struct AppRowView: View {
    let app: InstalledApp
    let isCustomized: Bool

    var body: some View {
        HStack(spacing: 10) {
            AppIconImageView(url: app.iconURL, size: 36)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(app.name)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                Text(app.bundleIdentifier)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            HStack(spacing: 4) {
                if isCustomized {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.system(size: 12))
                        .help("Custom icon applied")
                }
                if app.isLegacyIcon {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .font(.system(size: 12))
                        .help("Legacy (non-Retina) icon")
                }
            }
        }
        .padding(.vertical, 3)
        .contentShape(Rectangle())
    }
}
