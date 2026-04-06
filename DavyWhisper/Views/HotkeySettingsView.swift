import SwiftUI

struct HotkeySettingsView: View {
    @ObservedObject private var dictation = DictationViewModel.shared

    var body: some View {
        Form {
            if dictation.needsMicPermission {
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: "mic.slash.fill")
                            .font(.title2)
                            .foregroundStyle(.red)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(String(localized: "Microphone access required"))
                                .font(.headline)

                            Text(String(localized: "DavyWhisper needs microphone access to transcribe your speech. Grant access in System Settings."))
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()
                    }

                    HStack {
                        Button(String(localized: "Open System Settings")) {
                            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                        .buttonStyle(.borderedProminent)

                        Button(String(localized: "Grant Access")) {
                            dictation.requestMicPermission()
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .accessibilityIdentifier("com.davywhisper.settings.hotkeys.permissionBanner")
            }

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
