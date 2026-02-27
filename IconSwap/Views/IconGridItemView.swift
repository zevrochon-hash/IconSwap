import SwiftUI

struct IconGridItemView: View {
    let icon: IconResult
    let isApplied: Bool
    let onTap: () -> Void

    @State private var previewImage: NSImage?
    @State private var isHovered = false

    var body: some View {
        VStack(spacing: 8) {
            ZStack(alignment: .topTrailing) {
                iconPreview
                    .frame(width: 96, height: 96)
                    .clipShape(RoundedRectangle(cornerRadius: 21))
                    .shadow(color: .black.opacity(0.18), radius: 5, y: 2)
                    .scaleEffect(isHovered ? 1.06 : 1.0)
                    .animation(.spring(duration: 0.2), value: isHovered)

                if isApplied {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.white, .green)
                        .background(Circle().fill(.white).padding(2))
                        .offset(x: 6, y: -6)
                }
            }

            VStack(spacing: 2) {
                Text(icon.appName)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
                if !icon.creatorName.isEmpty {
                    Text("by \(icon.creatorName)")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Text("\(icon.downloads) dl")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(width: 130)
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isApplied
                      ? Color.accentColor.opacity(0.12)
                      : (isHovered ? Color(nsColor: .controlBackgroundColor) : Color.clear))
        )
        .onHover { isHovered = $0 }
        .onTapGesture { onTap() }
        .task(id: icon.id) {
            await loadPreview()
        }
        .help(icon.creatorName.isEmpty ? icon.appName : "\(icon.appName) by \(icon.creatorName)")
    }

    @ViewBuilder
    private var iconPreview: some View {
        if let image = previewImage {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else {
            ZStack {
                Color(nsColor: .windowBackgroundColor)
                ProgressView()
                    .scaleEffect(0.7)
            }
        }
    }

    private func loadPreview() async {
        guard previewImage == nil else { return }
        // Use the lowResPngUrl for fast thumbnail rendering in the grid.
        // The actual .icns is only downloaded when the user taps to apply.
        guard let url = URL(string: icon.lowResPngUrl) else { return }
        let image = await Task.detached(priority: .userInitiated) {
            guard let data = try? Data(contentsOf: url) else { return NSImage?.none }
            return NSImage(data: data)
        }.value
        previewImage = image
    }
}
