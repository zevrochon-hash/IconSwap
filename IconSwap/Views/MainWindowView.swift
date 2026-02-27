import SwiftUI

struct MainWindowView: View {
    @EnvironmentObject var appListVM: AppListViewModel
    @EnvironmentObject var iconGridVM: IconGridViewModel

    @State private var showFileiconAlert = false

    var body: some View {
        HSplitView {
            // Left panel — app list
            VStack(spacing: 0) {
                SearchBarView(query: $appListVM.searchQuery)
                FilterBarView(selected: $appListVM.selectedFilter)
                Divider()

                if appListVM.isScanning {
                    LoadingView(message: "Scanning installed apps…")
                } else {
                    AppListView()
                }

                if let error = appListVM.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(8)
                }
            }
            .frame(minWidth: 260, idealWidth: 300, maxWidth: 380)

            // Right panel — icon grid
            IconGridView()
                .frame(minWidth: 480)
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    Task { await appListVM.scanApps() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Refresh app list")
                .disabled(appListVM.isScanning)
            }
        }
        .task {
            await appListVM.scanApps()
        }
        .onAppear {
            if !FileiconInstaller.isInstalled {
                showFileiconAlert = true
            }
        }
        .alert("fileicon Required", isPresented: $showFileiconAlert) {
            Button("Copy Install Command") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(FileiconInstaller.installCommand, forType: .string)
            }
            Button("Open Settings") {
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            }
            Button("Dismiss", role: .cancel) {}
        } message: {
            Text(FileiconInstaller.installationInstructions)
        }
    }
}
