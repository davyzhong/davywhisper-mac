# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

DavyWhisper is a native macOS menu bar app for speech-to-text dictation and AI text processing. It supports 8 transcription engines (WhisperKit, Parakeet, SpeechAnalyzer, Qwen3, Voxtral, Groq, OpenAI, OpenAI Compatible), runs locally on Apple Silicon/Intel, and exposes a local HTTP API and CLI for automation.

- **macOS 14+**, **Swift 6**, **Xcode 16+**
- **SwiftData** for history/prompts persistence
- **MVVM** with `ServiceContainer` singleton for dependency injection
- **Plugin architecture** via `DavyWhisperPluginSDK` (Swift package) — all engines are bundled plugins
- Localization via `String(localized:)` with `Localizable.xcstrings`

## Build Commands

### Xcode (development)
```bash
cd davywhisper-mac
open DavyWhisper.xcodeproj
# Select DavyWhisper scheme, Cmd+B to build
```

### Command line (no signing)
```bash
xcodebuild -project DavyWhisper.xcodeproj \
  -scheme DavyWhisper \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  CODE_SIGN_IDENTITY='-' CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO
```

### Release build
```bash
./scripts/build-release-local.sh
# Or with signing:
./scripts/build-release-local.sh --sign
```

### Tests
```bash
# App tests
xcodebuild test -project DavyWhisper.xcodeproj -scheme DavyWhisper \
  -destination 'platform=macOS,arch=arm64' \
  -parallel-testing-enabled NO \
  CODE_SIGN_IDENTITY='-' CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO

# Plugin SDK tests
swift test --package-path DavyWhisperPluginSDK
```

### Check warnings
```bash
bash scripts/check_first_party_warnings.sh build-release/build.log
```

## Architecture

### App Entry Point
- `DavyWhisper/App/main.swift` — Manual `NSApplication` startup (no `@main` on AppDelegate)
- `DavyWhisper/App/DavyWhisperApp.swift` — SwiftUI app root
- `DavyWhisper/App/ServiceContainer.swift` — All services registered here; singletons with `static let shared`
- `DavyWhisper/App/AppConstants.swift` — Global constants (app version, ports)

### Service Layer
Services are the core business logic. All registered in `ServiceContainer`. Key ones:

| Service | Responsibility |
|---------|----------------|
| `AudioRecordingService` | Mic capture, streaming to engine |
| `AudioFileService` | Video/audio → 16kHz PCM conversion |
| `ModelManagerService` | Engine dispatch, model lifecycle |
| `HotkeyService` | Global hotkey registration (`CGEvent`) |
| `TextInsertionService` | Pasteboard + `CGEvent` text insertion |
| `ProfileService` | Per-app/URL profile matching and persistence |
| `HistoryService` | Transcription history (SwiftData) |
| `PromptProcessingService` | LLM orchestration, provider routing |
| `HTTPServer/` | Local REST API (`HTTPServer.swift` + `APIRouter.swift` + handlers) |
| `PluginManager` | Plugin discovery and lifecycle |
| `EventBus` | Typed pub/sub for internal events |
| `TranslationService` | Apple Translate wrapper |
| `SubtitleExporter` | SRT/VTT export with timestamps |

### Plugin System
All transcription engines and LLM providers are plugins in `Plugins/`. The SDK is at `DavyWhisperPluginSDK/`. To add a new plugin:
1. Create a bundle in `Plugins/YourPlugin/`
2. Implement the appropriate plugin protocol (`TranscriptionEnginePlugin`, `LLMProviderPlugin`, `PostProcessorPlugin`, `ActionPlugin`)
3. Include a `manifest.json`
4. Plugins register with `PluginManager`

### Data Models
- `Profile` — per-app/URL settings (SwiftData)
- `TranscriptionRecord` — history entry (SwiftData)
- `TranscriptionResult` — engine output (struct, not SwiftData)
- `PromptAction` — custom prompt definition (SwiftData)
- `Snippet` — text shortcut with `{{PLACEHOLDER}}` placeholders
- `DictionaryEntry` — term/correction pair
- `TermPack` — importable term pack bundle

### ViewModels
All ViewModels follow a `static let shared` singleton pattern and are `@Observable`. They interact with services via `ServiceContainer.shared.<service>`.

### Views
SwiftUI views in `Views/`. Settings UI is structured around `SettingsView` with sub-views per section. Menu bar / notch indicator lives in `NotchIndicatorView` / `OverlayIndicatorView`.

## Key Patterns

- **Menu bar app**: `LSUIElement = YES` in entitlements — no dock icon by default
- **SwiftData models**: Use `@Model` macro in `Models/`, persisted by `HistoryService` / `ProfileService`
- **Plugin communication**: Via `HostServices` protocol exposed through SDK — plugins call back into host app
- **Localization**: `String(localized:)` with `Localizable.xcstrings`. Add new strings there, not hardcoded
- **Error handling**: Custom `Error` types in `Models/`; services expose typed errors
- **Background work**: `Task { }` with `@MainActor` for UI updates; services use detached tasks for async work
