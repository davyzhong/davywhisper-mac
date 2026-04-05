import SwiftUI

struct HotkeySettingsView: View {
    @ObservedObject private var dictation = DictationViewModel.shared

    var body: some View {
        Form {
            Section(String(localized: "Dictation")) {
                HotkeyRecorderView(
                    label: dictation.hybridHotkeyLabel,
                    title: String(localized: "Dictation"),
                    subtitle: String(localized: "Short press to toggle, hold to push-to-talk."),
                    onRecord: { hotkey in
                        if let conflict = dictation.isHotkeyAssigned(hotkey, excluding: .hybrid) {
                            dictation.clearHotkey(for: conflict)
                        }
                        dictation.setHotkey(hotkey, for: .hybrid)
                    },
                    onClear: { dictation.clearHotkey(for: .hybrid) }
                )
                .accessibilityIdentifier("com.davywhisper.settings.recording.hotkey.hybrid")
            }

            Section(String(localized: "Prompt Palette")) {
                HotkeyRecorderView(
                    label: dictation.promptPaletteHotkeyLabel,
                    title: String(localized: "Palette shortcut"),
                    onRecord: { hotkey in
                        if let conflict = dictation.isHotkeyAssigned(hotkey, excluding: .promptPalette) {
                            dictation.clearHotkey(for: conflict)
                        }
                        dictation.setHotkey(hotkey, for: .promptPalette)
                    },
                    onClear: { dictation.clearHotkey(for: .promptPalette) }
                )
                .accessibilityIdentifier("com.davywhisper.settings.recording.hotkey.promptPalette")

                Text(String(localized: "Select text in any app, press the shortcut, and choose a prompt to process the text."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(minWidth: 500, minHeight: 300)
    }
}
