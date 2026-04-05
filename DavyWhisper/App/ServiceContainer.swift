import Foundation
import Combine

@MainActor
final class ServiceContainer: ObservableObject {
    static let shared = ServiceContainer()

    // Services
    let modelManagerService: ModelManagerService
    let audioFileService: AudioFileService
    let audioRecordingService: AudioRecordingService
    let hotkeyService: HotkeyService
    let textInsertionService: TextInsertionService
    let historyService: HistoryService
    let textDiffService: TextDiffService
    let profileService: ProfileService
    let snippetService: SnippetService
    let soundService: SoundService
    let audioDeviceService: AudioDeviceService
    let promptActionService: PromptActionService
    let promptProcessingService: PromptProcessingService
    let pluginManager: PluginManager
    let pluginRegistryService: PluginRegistryService
    let termPackRegistryService: TermPackRegistryService
    let memoryService: MemoryService
    let appFormatterService: AppFormatterService
    let accessibilityAnnouncementService: AccessibilityAnnouncementService
    let errorLogService: ErrorLogService
    let pluginCredentialService: PluginCredentialService

    // HTTP API
    let httpServer: HTTPServer
    let apiServerViewModel: APIServerViewModel

    // ViewModels
    let fileTranscriptionViewModel: FileTranscriptionViewModel
    let settingsViewModel: SettingsViewModel
    let dictationViewModel: DictationViewModel
    let historyViewModel: HistoryViewModel
    let profilesViewModel: ProfilesViewModel
    let snippetsViewModel: SnippetsViewModel
    let promptActionsViewModel: PromptActionsViewModel

    private init() {
        // Services
        modelManagerService = ModelManagerService()
        audioFileService = AudioFileService()
        audioRecordingService = AudioRecordingService()
        hotkeyService = HotkeyService()
        textInsertionService = TextInsertionService()
        historyService = HistoryService()
        textDiffService = TextDiffService()
        profileService = ProfileService()
        snippetService = SnippetService()
        soundService = SoundService()
        audioDeviceService = AudioDeviceService()
        promptActionService = PromptActionService()
        promptProcessingService = PromptProcessingService()
        pluginManager = PluginManager()
        pluginRegistryService = PluginRegistryService()
        termPackRegistryService = TermPackRegistryService()
        memoryService = MemoryService(promptProcessingService: promptProcessingService)
        appFormatterService = AppFormatterService()
        promptProcessingService.memoryService = memoryService
        accessibilityAnnouncementService = AccessibilityAnnouncementService()
        errorLogService = ErrorLogService()
        pluginCredentialService = PluginCredentialService()

        // ViewModels (created before HTTP API so DictationViewModel is available)
        fileTranscriptionViewModel = FileTranscriptionViewModel(
            modelManager: modelManagerService,
            audioFileService: audioFileService
        )
        settingsViewModel = SettingsViewModel(modelManager: modelManagerService)
        dictationViewModel = DictationViewModel(
            audioRecordingService: audioRecordingService,
            textInsertionService: textInsertionService,
            hotkeyService: hotkeyService,
            modelManager: modelManagerService,
            settingsViewModel: settingsViewModel,
            historyService: historyService,
            profileService: profileService,
            snippetService: snippetService,
            soundService: soundService,
            audioDeviceService: audioDeviceService,
            promptActionService: promptActionService,
            promptProcessingService: promptProcessingService,
            appFormatterService: appFormatterService,
            accessibilityAnnouncementService: accessibilityAnnouncementService,
            errorLogService: errorLogService
        )


        // HTTP API
        let router = APIRouter()
        let handlers = APIHandlers(modelManager: modelManagerService, audioFileService: audioFileService, historyService: historyService, profileService: profileService, dictationViewModel: dictationViewModel)
        handlers.register(on: router)
        httpServer = HTTPServer(router: router)
        apiServerViewModel = APIServerViewModel(httpServer: httpServer)
        historyViewModel = HistoryViewModel(
            historyService: historyService,
            textDiffService: textDiffService
        )
        profilesViewModel = ProfilesViewModel(
            profileService: profileService,
            historyService: historyService,
            settingsViewModel: settingsViewModel
        )
        snippetsViewModel = SnippetsViewModel(snippetService: snippetService)
        promptActionsViewModel = PromptActionsViewModel(
            promptActionService: promptActionService,
            promptProcessingService: promptProcessingService
        )

        // Set shared references
        FileTranscriptionViewModel._shared = fileTranscriptionViewModel
        SettingsViewModel._shared = settingsViewModel
        DictationViewModel._shared = dictationViewModel
        APIServerViewModel._shared = apiServerViewModel
        HistoryViewModel._shared = historyViewModel
        ProfilesViewModel._shared = profilesViewModel
        SnippetsViewModel._shared = snippetsViewModel
        PromptActionsViewModel._shared = promptActionsViewModel

        // Plugin system
        EventBus.shared = EventBus()
        PluginManager.shared = pluginManager
        PluginRegistryService.shared = pluginRegistryService
        TermPackRegistryService.shared = termPackRegistryService

        settingsViewModel.observePluginManager()
    }

    func initialize() async {
        guard !AppConstants.isRunningTests else { return }

        hotkeyService.setup()
        dictationViewModel.registerInitialProfileHotkeys()
        let retentionDays = UserDefaults.standard.integer(forKey: UserDefaultsKeys.historyRetentionDays)
        if retentionDays > 0 { historyService.purgeOldRecords(retentionDays: retentionDays) }

        if apiServerViewModel.isEnabled {
            apiServerViewModel.startServer()
        }

        pluginManager.setProfileNamesProvider { [weak self] in
            self?.profileService.profiles.map(\.name) ?? []
        }
        pluginManager.scanAndLoadPlugins()

        // Re-restore provider selection now that plugins are loaded
        modelManagerService.restoreProviderSelection()

        // Validate LLM provider selection against loaded plugins
        promptProcessingService.validateSelectionAfterPluginLoad()

        // Check for plugin updates in background
        pluginRegistryService.checkForUpdatesInBackground()

        // Check for term pack updates in background
        termPackRegistryService.checkForUpdatesInBackground()

        // Start memory service
        memoryService.startListening()

        // Migrate profiles: whisper → paraformer (one-time, guarded by UserDefaults flag)
        profileService.migrateDefaultEngine(userDefaults: UserDefaults.standard)

        // Migrate stale cloudModelOverride in profiles
        for profile in profileService.profiles {
            guard let modelOverride = profile.cloudModelOverride,
                  let engineOverride = profile.engineOverride,
                  let plugin = PluginManager.shared.transcriptionEngine(for: engineOverride) else { continue }
            let validIds = plugin.transcriptionModels.map(\.id)
            if !validIds.contains(modelOverride) {
                profile.cloudModelOverride = nil
            }
        }
    }
}
