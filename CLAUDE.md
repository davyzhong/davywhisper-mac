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

### Project generation (required after project.yml changes)
```bash
xcodegen generate
# or:
./scripts/generate-projects.sh
```

The Xcode project (`DavyWhisper.xcodeproj/project.pbxproj`) is **generated** from `project.yml` via XcodeGen. It is listed in `.gitignore` and should not be edited manually. Always run `xcodegen generate` after modifying `project.yml`.

### Xcode (development)
```bash
xcodegen generate  # regenerate project
open DavyWhisper.xcodeproj
# Select DavyWhisper scheme, Cmd+B to build
```

### Command line (no signing)
```bash
xcodegen generate  # ensure project is up to date
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
# Unit tests (all schemes auto-generated, DavyWhisper.xcscheme runs DavyWhisperTests only)
xcodebuild test -project DavyWhisper.xcodeproj -scheme DavyWhisper \
  -destination 'platform=macOS,arch=arm64' \
  CODE_SIGN_IDENTITY='-' CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO

# UITests (requires display session — will skip in headless/CI)
xcodebuild test -project DavyWhisper.xcodeproj -scheme DavyWhisperUITests \
  -destination 'platform=macOS,arch=arm64' \
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
All transcription engines and LLM providers are plugins in `Plugins/`. The SDK is at `DavyWhisperPluginSDK/`. Plugin bundles are built by XcodeGen (defined in `project.yml`) and embedded in `Contents/Resources/`. PluginManager scans both `Contents/PlugIns/` and `Contents/Resources/` to discover bundles.

To add a new plugin:
1. Create a bundle directory in `Plugins/YourPlugin/` with `YourPlugin.swift` + `manifest.json`
2. Implement the appropriate plugin protocol (`TranscriptionEnginePlugin`, `LLMProviderPlugin`, `PostProcessorPlugin`, `ActionPlugin`)
3. Add a target block in `project.yml` under `targets:`
4. Add `- target: YourPlugin` + `embed: true` to DavyWhisper's dependencies
5. Run `xcodegen generate` to regenerate the project

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

## China Mirror Requirements

This project targets Chinese users. All external resource downloads must use domestic mirrors:

| Service | Mirror URL | Original |
|---------|-----------|----------|
| HuggingFace models | `hf-mirror.com` | `huggingface.co` |
| GitHub Releases | `mirror.ghproxy.com` | `github.com` |
| NPM packages | `registry.npmmirror.com` | `registry.npmjs.org` |
| PyPI packages | `pypi.tuna.tsinghua.edu.cn` | `pypi.org` |

**Rules:**
- Hardcode mirror URLs in source code — do not rely on environment variables alone
- `HF_ENDPOINT=hf-mirror.com` is already set in `main.swift` as default
- Any new model download logic must use `hf-mirror.com` as the default URL
- Provide a fallback toggle in Advanced Settings for users who can access originals directly

## Testing Framework

Tests live in `DavyWhisperTests/` (XCTest) and `DavyWhisperUITests/` (XCUITest).
Key testing infrastructure:
- `DavyWhisperTests/Support/TestSupport.swift` — temp directory isolation
- `DavyWhisperTests/Support/TestServiceContainer.swift` — isolated service container with temp dirs + static ref cleanup
- `DavyWhisperTests/Mocks/` — mock implementations for service/protocol testing
- `DavyWhisper/Protocols/` — protocol definitions for testability (AudioRecordingProtocol, HotkeyProtocol, etc.)

See `docs/superpowers/specs/2026-04-03-testing-framework-design.md` for the full testing framework design.

## Phase Completion Rule

**Every phase must close the loop before moving to the next:**

1. Update all relevant project docs (README, design docs, `docs/superpowers/specs/`, etc.)
2. Commit with a descriptive message covering what changed
3. Push to remote

Do not proceed to the next phase without completing all three steps.

## Key Patterns

- **Menu bar app**: `LSUIElement = YES` in entitlements — no dock icon by default
- **SwiftData models**: Use `@Model` macro in `Models/`, persisted by `HistoryService` / `ProfileService`
- **Plugin communication**: Via `HostServices` protocol exposed through SDK — plugins call back into host app
- **Localization**: `String(localized:)` with `Localizable.xcstrings`. Add new strings there, not hardcoded
- **Error handling**: Custom `Error` types in `Models/`; services expose typed errors
- **Background work**: `Task { }` with `@MainActor` for UI updates; services use detached tasks for async work
