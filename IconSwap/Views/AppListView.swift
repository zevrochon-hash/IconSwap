import SwiftUI

struct AppListView: View {
    @EnvironmentObject var appListVM: AppListViewModel
    @EnvironmentObject var iconGridVM: IconGridViewModel

    var body: some View {
        Group {
            if appListVM.filteredApps.isEmpty {
                EmptyStateView(
                    title: "No Apps Found",
                    systemImage: "tray",
                    message: "Try a different search or filter."
                )
            } else {
                List(appListVM.filteredApps, selection: $appListVM.selectedApp) { app in
                    AppRowView(
                        app: app,
                        isCustomized: appListVM.customizedBundleIDs.contains(app.bundleIdentifier)
                    )
                    .tag(app)
                }
                .listStyle(.sidebar)
            }
        }
        .onChange(of: appListVM.selectedApp) { newApp in
            iconGridVM.selectedApp = newApp
        }
    }
}
