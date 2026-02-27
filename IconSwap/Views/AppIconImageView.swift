import SwiftUI

/// Loads and displays a .icns file from a local URL.
struct AppIconImageView: View {
    let url: URL
    var size: CGFloat = 36

    @State private var image: NSImage?

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Image(systemName: "app.dashed")
                    .font(.system(size: size * 0.7))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
        .task(id: url) {
            // Load on background thread
            let loaded = await Task.detached(priority: .userInitiated) {
                NSImage(contentsOf: url)
            }.value
            image = loaded
        }
    }
}
