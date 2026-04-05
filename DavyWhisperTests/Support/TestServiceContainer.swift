import Foundation
@testable import DavyWhisper

/// Test-ready service container that provides isolated real service instances.
///
/// Usage:
///   let container = try TestServiceContainer()
///   // use container.dictationViewModel, container.historyService, etc.
///   container.tearDown()
///
/// All services use temporary directories for SwiftData isolation.
/// Static shared references are managed here and reset in tearDown()
/// to prevent cross-test pollution.
@MainActor
final class TestServiceContainer {

    // MARK: - Tier C: Directory-isolated services

    let tempDirectory: URL
    let historyService: HistoryService
    let profileService: ProfileService
    let snippetService: SnippetService
    let promptActionService: PromptActionService

    // MARK: - Tier C: Stateless / simple services

    let textDiffService: TextDiffService
    let soundService: SoundService
    let errorLogService: ErrorLogService

    // MARK: - Tier B: Services with complex dependencies

    let modelManagerService: ModelManagerService
    let audioFileService: AudioFileService
    let audioRecordingService: AudioRecordingService
    let hotkeyService: HotkeyService
    let textInsertionService: TextInsertionService
    let audioDeviceService: AudioDeviceService
    let promptProcessingService: PromptProcessingService
    let memoryService: MemoryService
    let appFormatterService: AppFormatterService
    let audioRecorderService: AudioRecorderService
    let accessibilityAnnouncementService: AccessibilityAnnouncementService

    // MARK: - Tier B: Plugin / HTTP

    let pluginManager: PluginManager
    let pluginRegistryService: PluginRegistryService
    let termPackRegistryService: TermPackRegistryService
    let httpServer: HTTPServer
    /// Mock HTTP server used for APIServerViewModel tests that need to simulate failures.
    let mockHTTPServer: MockHTTPServer

    // MARK: - ViewModels

    let dictationViewModel: DictationViewModel
    let settingsViewModel: SettingsViewModel
    let historyViewModel: HistoryViewModel
    let profilesViewModel: ProfilesViewModel
    let snippetsViewModel: SnippetsViewModel
    let promptActionsViewModel: PromptActionsViewModel
    let audioRecorderViewModel: AudioRecorderViewModel
    let apiServerViewModel: APIServerViewModel

    // MARK: - Initialization

    init() throws {
        tempDirectory = try TestSupport.makeTemporaryDirectory()
        let tmp = tempDirectory

        // Tier C: Directory-isolated services
        historyService = HistoryService(appSupportDirectory: tmp)
        profileService = ProfileService(appSupportDirectory: tmp)
        snippetService = SnippetService(appSupportDirectory: tmp)
        promptActionService = PromptActionService(appSupportDirectory: tmp)

        // Tier C: Stateless / simple services
        textDiffService = TextDiffService()
        soundService = SoundService()
        errorLogService = ErrorLogService()

        // Tier B: Plugin system (order matters)
        pluginManager = PluginManager()
        pluginRegistryService = PluginRegistryService()
        termPackRegistryService = TermPackRegistryService()
        EventBus.shared = EventBus()
        PluginManager.shared = pluginManager
        PluginRegistryService.shared = pluginRegistryService
        TermPackRegistryService.shared = termPackRegistryService

        // Tier B: Hardware services
        modelManagerService = ModelManagerService()
        audioFileService = AudioFileService()
        audioRecordingService = AudioRecordingService()
        hotkeyService = HotkeyService()
        textInsertionService = TextInsertionService()
        audioDeviceService = AudioDeviceService()

        // Prompt pipeline (order matters)
        appFormatterService = AppFormatterService()
        promptProcessingService = PromptProcessingService()
        memoryService = MemoryService(promptProcessingService: promptProcessingService)
        promptProcessingService.memoryService = memoryService
        audioRecorderService = AudioRecorderService()
        accessibilityAnnouncementService = AccessibilityAnnouncementService()

        // HTTP API
        let router = APIRouter()

        // ViewModels
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

        // HTTP handlers with dictationViewModel injected
        let handlers = APIHandlers(
            modelManager: modelManagerService,
            audioFileService: audioFileService,
            historyService: historyService,
            profileService: profileService,
            dictationViewModel: dictationViewModel
        )
        handlers.register(on: router)
        httpServer = HTTPServer(router: router)
        mockHTTPServer = MockHTTPServer(router: router)

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
        audioRecorderViewModel = AudioRecorderViewModel(
            recorderService: audioRecorderService,
            modelManager: modelManagerService
        )
        apiServerViewModel = APIServerViewModel(httpServer: mockHTTPServer)

        // Set static shared references
        DictationViewModel._shared = dictationViewModel
        SettingsViewModel._shared = settingsViewModel
        APIServerViewModel._shared = apiServerViewModel
        HistoryViewModel._shared = historyViewModel
        ProfilesViewModel._shared = profilesViewModel
        SnippetsViewModel._shared = snippetsViewModel
        PromptActionsViewModel._shared = promptActionsViewModel
        AudioRecorderViewModel._shared = audioRecorderViewModel
    }

    // MARK: - TearDown

    /// Resets all static shared references and removes the temp directory.
    /// Call this in XCTestCase.tearDown().
    func tearDown() {
        DictationViewModel._shared = nil
        SettingsViewModel._shared = nil
        APIServerViewModel._shared = nil
        HistoryViewModel._shared = nil
        ProfilesViewModel._shared = nil
        SnippetsViewModel._shared = nil
        PromptActionsViewModel._shared = nil
        AudioRecorderViewModel._shared = nil
        EventBus.shared = nil
        PluginManager.shared = nil
        PluginRegistryService.shared = nil
        TermPackRegistryService.shared = nil

        TestSupport.remove(tempDirectory)
    }
}
