import SwiftUI

struct AdvancedSettingsView: View {
    @ObservedObject private var apiServerViewModel = APIServerViewModel.shared
    @ObservedObject private var advancedViewModel: AdvancedSettingsViewModel
    @ObservedObject private var memoryService = ServiceContainer.shared.memoryService
    @ObservedObject private var promptProcessingService = ServiceContainer.shared.promptProcessingService
    @ObservedObject private var modelManager = ServiceContainer.shared.modelManagerService
    @ObservedObject private var dictation = DictationViewModel.shared
    #if !APPSTORE
    #endif
    @State private var showClearMemoryConfirmation = false

    @AppStorage(UserDefaultsKeys.historyRetentionDays) private var historyRetentionDays: Int = 0
    @AppStorage(UserDefaultsKeys.saveAudioWithHistory) private var saveAudioWithHistory: Bool = false

    init(advancedViewModel: AdvancedSettingsViewModel = AdvancedSettingsViewModel()) {
        _advancedViewModel = ObservedObject(wrappedValue: advancedViewModel)
    }

    var body: some View {
        Form {
            // MARK: - Memory
            Section(String(localized: "Memory")) {
                Toggle(String(localized: "Enable Memory"), isOn: $memoryService.isEnabled)
                    .accessibilityIdentifier("com.davywhisper.settings.advanced.memoryToggle")
                Text(String(localized: "Automatically extracts facts, preferences and patterns from your transcriptions using an LLM. Memories are injected into prompt context."))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                DisclosureGroup(String(localized: "Advanced Settings"), isExpanded: .constant(false)) {
                    if memoryService.isEnabled {
                        Picker(String(localized: "Extraction Provider"), selection: $memoryService.extractionProviderId) {
                            Text(String(localized: "None")).tag("")
                            ForEach(promptProcessingService.availableProviders, id: \.id) { provider in
                                Text(provider.displayName).tag(provider.id)
                            }
                        }
                        .accessibilityIdentifier("com.davywhisper.settings.advanced.extractionProvider")

                        if !memoryService.extractionProviderId.isEmpty {
                            let models = promptProcessingService.modelsForProvider(memoryService.extractionProviderId)
                            if !models.isEmpty {
                                Picker(String(localized: "Extraction Model"), selection: $memoryService.extractionModel) {
                                    Text(String(localized: "Default")).tag("")
                                    ForEach(models, id: \.id) { model in
                                        Text(model.displayName).tag(model.id)
                                    }
                                }
                            }
                        }

                        Stepper(value: $memoryService.minimumTextLength, in: 10...200, step: 10) {
                            HStack {
                                Text(String(localized: "Min. text length"))
                                Spacer()
                                Text("\(memoryService.minimumTextLength)")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Text(String(localized: "Transcriptions shorter than this are skipped for memory extraction."))
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        DisclosureGroup(String(localized: "Extraction Prompt")) {
                            TextEditor(text: $memoryService.extractionPrompt)
                                .font(.system(.caption, design: .monospaced))
                                .frame(minHeight: 120)
                                .border(.separator)

                            Button(String(localized: "Reset to Default")) {
                                memoryService.extractionPrompt = MemoryService.defaultExtractionPrompt
                            }
                            .font(.caption)
                        }

                        HStack {
                            Image(systemName: "circle.fill")
                                .foregroundStyle(memoryService.extractionProviderId.isEmpty ? .orange : .green)
                                .font(.caption2)
                                .accessibilityHidden(true)
                            if memoryService.extractionProviderId.isEmpty {
                                Text(String(localized: "Select an extraction provider to start collecting memories."))
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text(String(localized: "Memory extraction active"))
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Button(role: .destructive) {
                            showClearMemoryConfirmation = true
                        } label: {
                            Label(String(localized: "Clear All Memories"), systemImage: "trash")
                        }
                        .accessibilityIdentifier("com.davywhisper.settings.advanced.clearMemories")
                        .confirmationDialog(
                            String(localized: "Clear All Memories?"),
                            isPresented: $showClearMemoryConfirmation
                        ) {
                            Button(String(localized: "Clear All"), role: .destructive) {
                                Task { await memoryService.clearAllMemories() }
                            }
                        } message: {
                            Text(String(localized: "This will permanently delete all stored memories from all plugins. This cannot be undone."))
                        }
                    }
                }
            }

            // MARK: - Recording
            Section(String(localized: "Recording")) {
                Picker(String(localized: "Auto-unload model"), selection: Binding(
                    get: { modelManager.autoUnloadSeconds },
                    set: { modelManager.autoUnloadSeconds = $0 }
                )) {
                    Text(String(localized: "Never")).tag(0)
                    Divider()
                    Text(String(localized: "Immediate")).tag(-1)
                    Text(String(localized: "After 2 minutes")).tag(120)
                    Text(String(localized: "After 5 minutes")).tag(300)
                    Text(String(localized: "After 10 minutes")).tag(600)
                    Text(String(localized: "After 30 minutes")).tag(1800)
                    Text(String(localized: "After 1 hour")).tag(3600)
                }
                .accessibilityIdentifier("com.davywhisper.settings.advanced.autoUnloadModel")

                Text(String(localized: "Automatically unloads local models from memory after inactivity. It reloads when needed. Does not affect cloud engines."))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Toggle(String(localized: "HuggingFace Mirror"), isOn: Binding(
                    get: { UserDefaults.standard.bool(forKey: UserDefaultsKeys.useHuggingFaceMirror) },
                    set: { newValue in
                        UserDefaults.standard.set(newValue, forKey: UserDefaultsKeys.useHuggingFaceMirror)
                    }
                ))
                .accessibilityIdentifier("com.davywhisper.settings.advanced.hfMirror")

                Text(String(localized: "Uses hf-mirror.com for faster downloads in China. Restart required."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // MARK: - History
            Section(String(localized: "History")) {
                Toggle(String(localized: "Save audio with transcriptions"), isOn: $saveAudioWithHistory)
                    .accessibilityIdentifier("com.davywhisper.settings.advanced.saveAudio")
                Text(String(localized: "Stores a WAV recording alongside each transcription. Uses approximately 1 MB per 30 seconds."))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Picker(String(localized: "Auto-delete after"), selection: $historyRetentionDays) {
                    Text(String(localized: "Unlimited")).tag(0)
                    Text(String(localized: "30 days")).tag(30)
                    Text(String(localized: "60 days")).tag(60)
                    Text(String(localized: "90 days")).tag(90)
                    Text(String(localized: "180 days")).tag(180)
                }
                Text(String(localized: "Older entries are automatically removed at app launch."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // MARK: - API Server
            Section(String(localized: "API Server")) {
                Toggle(String(localized: "Enable API Server"), isOn: $apiServerViewModel.isEnabled)
                    .accessibilityIdentifier("com.davywhisper.settings.advanced.apiServer")
                    .onChange(of: apiServerViewModel.isEnabled) { _, enabled in
                        if enabled {
                            apiServerViewModel.startServer()
                        } else {
                            apiServerViewModel.stopServer()
                        }
                    }

                Text(String(localized: "Advanced automation interface for local tools. Disabled by default and bound to 127.0.0.1 only."))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if apiServerViewModel.isEnabled {
                    HStack {
                        Image(systemName: "circle.fill")
                            .foregroundStyle(apiServerViewModel.isRunning ? .green : .orange)
                            .font(.caption2)
                            .accessibilityHidden(true)
                        Text(apiServerViewModel.isRunning
                             ? String(localized: "Running on port \(String(apiServerViewModel.port))")
                             : String(localized: "Not running"))
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }

                    if let error = apiServerViewModel.errorMessage {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                            .font(.callout)
                    }
                }
            }

            #if !APPSTORE
            // MARK: - Command Line Tool
            Section(String(localized: "Command Line Tool")) {
                HStack {
                    Image(systemName: "circle.fill")
                        .foregroundStyle(advancedViewModel.cliInstalled ? .green : .orange)
                        .font(.caption2)
                        .accessibilityHidden(true)
                    if advancedViewModel.cliInstalled {
                        Text(String(localized: "Installed at /usr/local/bin/davywhisper"))
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    } else {
                        Text(String(localized: "Not installed"))
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }

                if advancedViewModel.cliInstalled {
                    Button(String(localized: "Uninstall")) {
                        advancedViewModel.uninstallCLI()
                    }
                } else {
                    Button(String(localized: "Install Command Line Tool")) {
                        advancedViewModel.installCLI()
                    }
                }

                Text(String(localized: "Requires the API server to be running. The CLI tool connects to DavyWhisper's API for fast transcription without model cold starts."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            #endif

            // MARK: - Usage Examples
            if apiServerViewModel.isEnabled {
                Section(String(localized: "Usage Examples")) {
                    #if !APPSTORE
                    if advancedViewModel.cliInstalled {
                        cliExamples
                    } else {
                        curlExamples
                    }
                    #else
                    curlExamples
                    #endif
                }
            }

        }
        .formStyle(.grouped)
        .padding()
        .frame(minWidth: 500, minHeight: 300)
        .onAppear {
            #if !APPSTORE
            advancedViewModel.checkCLIInstallation()
            #endif
        }
    }

    // MARK: - Examples

    #if !APPSTORE
    private var cliExamples: some View {
        VStack(alignment: .leading, spacing: 8) {
            exampleRow(String(localized: "Show help:"), "davywhisper --help")
            Divider()
            exampleRow(String(localized: "Check status:"), "davywhisper status")
            Divider()
            exampleRow(String(localized: "Transcribe audio:"), "davywhisper transcribe audio.wav")
            Divider()
            exampleRow(String(localized: "Transcribe with language:"), "davywhisper transcribe audio.wav --language zh")
            Divider()
            exampleRow(String(localized: "JSON output:"), "davywhisper transcribe audio.wav --json")
            Divider()
            exampleRow(String(localized: "Pipe to clipboard:"), "davywhisper transcribe audio.wav | pbcopy")
            Divider()
            exampleRow(String(localized: "List models:"), "davywhisper models")
        }
    }
    #endif

    private var curlExamples: some View {
        VStack(alignment: .leading, spacing: 8) {
            exampleRow(String(localized: "Check status:"), "curl http://127.0.0.1:\(apiServerViewModel.port)/v1/status")
            Divider()
            exampleRow(String(localized: "Transcribe audio:"), "curl -X POST http://127.0.0.1:\(apiServerViewModel.port)/v1/transcribe \\\n  -F \"file=@audio.wav\"")
            Divider()
            exampleRow(String(localized: "List models:"), "curl http://127.0.0.1:\(apiServerViewModel.port)/v1/models")
        }
    }

    private func exampleRow(_ label: String, _ command: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.callout)
                .foregroundStyle(.secondary)
            HStack {
                Text(command)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                Spacer()
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(command, forType: .string)
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                .help(String(localized: "Copy"))
            }
        }
    }
}
