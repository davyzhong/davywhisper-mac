import SwiftUI

struct DictionarySnippetsSettingsView: View {
    @State private var selectedSubTab = 0

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $selectedSubTab) {
                Text(String(localized: "Dictionary")).tag(0)
                Text(String(localized: "Snippets")).tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.bottom, 8)

            if selectedSubTab == 0 {
                DictionarySettingsView()
            } else {
                SnippetsSettingsView()
            }
        }
    }
}
