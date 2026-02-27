import SwiftUI
import UniformTypeIdentifiers

struct IconGridView: View {
    @EnvironmentObject var iconGridVM: IconGridViewModel
    @EnvironmentObject var appListVM: AppListViewModel

    @State private var isImporting = false

    private let columns = [GridItem(.adaptive(minimum: 148, maximum: 180), spacing: 12)]

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider()
            content
        }
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: [UTType(filenameExtension: "icns") ?? .data],
            allowsMultipleSelection: false
        ) { result in
            guard case .success(let urls) = result, let url = urls.first,
                  let app = iconGridVM.selectedApp else { return }
            url.startAccessingSecurityScopedResource()
            Task {
                await iconGridVM.importCustomIcon(from: url, for: app)
                appListVM.refreshCustomizedSet()
                url.stopAccessingSecurityScopedResource()
            }
        }
        .alert("Error", isPresented: .init(
            get: { iconGridVM.errorMessage != nil },
            set: { if !$0 { iconGridVM.errorMessage = nil } }
        )) {
            Button("OK") { iconGridVM.errorMessage = nil }
        } message: {
            Text(iconGridVM.errorMessage ?? "")
        }
    }

    // MARK: - Header

    @ViewBuilder
    private var headerBar: some View {
        if let app = iconGridVM.selectedApp {
            HStack(spacing: 12) {
                AppIconImageView(url: app.iconURL, size: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 2) {
                    Text(app.name).font(.headline)
                    Text(iconGridVM.isLoading
                         ? "Loading…"
                         : "\(iconGridVM.icons.count) icons available")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if appListVM.customizedBundleIDs.contains(app.bundleIdentifier) {
                    Button("Restore Original") {
                        Task {
                            await iconGridVM.restoreIcon(for: app)
                            appListVM.refreshCustomizedSet()
                        }
                    }
                    .buttonStyle(.bordered)
                }

                Button("Import .icns…") {
                    isImporting = true
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if iconGridVM.selectedApp == nil {
            EmptyStateView(
                title: "Select an App",
                systemImage: "square.grid.2x2",
                message: "Pick an app from the left to browse alternative icons."
            )
        } else if iconGridVM.isLoading && iconGridVM.icons.isEmpty {
            LoadingView(message: "Fetching icons…")
        } else if iconGridVM.icons.isEmpty {
            EmptyStateView(
                title: "No Icons Found",
                systemImage: "photo.on.rectangle.angled",
                message: "No icons available on macosicons.com for this app yet."
            )
        } else {
            iconGrid
        }
    }

    private var iconGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(iconGridVM.icons) { icon in
                    IconGridItemView(
                        icon: icon,
                        isApplied: iconGridVM.appliedIconID == icon.id
                    ) {
                        guard let app = iconGridVM.selectedApp else { return }
                        Task {
                            await iconGridVM.applyIcon(icon, toApp: app)
                            appListVM.refreshCustomizedSet()
                        }
                    }
                }

                // Load more trigger
                if iconGridVM.currentPage < iconGridVM.totalPages {
                    Color.clear
                        .frame(height: 1)
                        .onAppear {
                            Task { await iconGridVM.loadNextPage() }
                        }
                }
            }
            .padding(16)
        }
    }
}
