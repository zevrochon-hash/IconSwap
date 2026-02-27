import SwiftUI

struct FilterBarView: View {
    @Binding var selected: AppFilter

    var body: some View {
        Picker("Filter", selection: $selected) {
            ForEach(AppFilter.allCases) { filter in
                Text(filter.rawValue).tag(filter)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 10)
        .padding(.bottom, 8)
        .labelsHidden()
    }
}
