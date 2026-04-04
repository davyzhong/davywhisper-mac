# DavyWhisper v1.x Refactoring Design

**Date:** 2026-04-04
**Status:** Draft (v2 — post spec-review fixes)
**Author:** Claude Code (brainstorming session with user)
**Reviewed-by:** spec-document-reviewer (14 issues found, all addressed)

---

## 1. Background

DavyWhisper is a macOS menu bar speech-to-text app forked from TypeWhisper (German → Simplified Chinese). The fork phases 1-6 are complete. The codebase sits at:

- **~35,000 lines** Swift across **144 files**
- **97 main app** Swift files, **36 services**, **14 ViewModels**, **30 views**
- **7 source plugins** in `Plugins/`: WhisperKit, Deepgram, ElevenLabs, Paraformer, Qwen3, OpenAICompatible, LiveTranscript
- **4 downloadable-only LLM plugins** in `plugins.json`: GLM, Kimi, MiniMax (no source directories)
- **~330 unit tests** passing, coverage estimated ~8-9% overall (per testing-framework-design.md baseline)
- **9 Settings tabs** (already merged from 14 in earlier phases)

**Verified plugin provider IDs** (from source code):
| Plugin | `providerId` |
|--------|-------------|
| WhisperKit | `"whisper"` |
| Paraformer | `"paraformer"` |
| Qwen3 | `"qwen3"` |
| Deepgram | `"deepgram"` |
| ElevenLabs | `"elevenlabs"` |

Three critical gaps exist:

1. **Chinese ASR accuracy**: Paraformer plugin exists in code but is not the default engine. WhisperKit (~8-10% CER on Chinese) is still the default. Target: ~2-3% CER.
2. **Plugin registry bloat**: `plugins.json` still lists WebhookPlugin (downloadable-only) and 3 separate LLM plugins. These should be cleaned up and LLM plugins unified.
3. **Test coverage**: ~8-9% overall is far below the 75% stability contract target.

---

## 2. Goals

| Dimension | Current | Target |
|-----------|---------|--------|
| Chinese ASR accuracy | ~8-10% CER (WhisperKit base) | ~2-3% CER (Paraformer) |
| Out-of-box usability | Requires model download | Works immediately (151MB bundled) |
| Default engine | None (nil on fresh install) | Paraformer |
| Downloadable plugins in plugins.json | 9 entries | 5 entries (remove Webhook + 3 LLM) |
| LLM providers | 3 separate downloadable plugins | 1 unified OpenAICompatiblePlugin with presets |
| Settings tabs | 9 (already merged) | 9 (no change needed) |
| Test coverage | ~8-9% (measured baseline) | >=75% (CI gate) |

---

## 3. Execution Model

**P9 Tech Lead orchestrator** manages three workstreams. Key path sequencing: C-line runs first as the critical path. A-line and B-line start after C-line completes.

```
Phase 0: Baseline — Measure current test coverage
    |
    v
Phase 1: C-line (Critical Path — Chinese ASR Experience)
    ├── C1: ModelManager default engine
    ├── C2: Profile migration
    ├── C3: Model bundling
    └── C4: E2E verification
    |
    v
Phase 2: A-line + B-line (Parallel)
    ├── A-line: Simplification (plugin cleanup, LLM unification)
    └── B-line: Test coverage >=75% CI gate
```

**Why C-line must complete first**: A-line modifies `plugins.json` and plugin discovery logic. C-line modifies `ModelManagerService` default engine selection. Running them simultaneously risks merge conflicts in shared files (`SettingsView.swift`, `project.yml`, `PluginManager.swift`). Completing C-line first establishes a stable baseline for A-line changes.

### Module-Level TDD

Every module change follows this cycle:

1. **Red**: Write all tests for the module (covering current behavior + expected new behavior)
2. **Green**: Implement changes until all tests pass
3. **Refactor**: Clean up within the module
4. **Gate**: Coverage for the module must meet threshold before merge

This applies to: ModelManagerService, ProfileService, OpenAICompatiblePlugin, Settings tabs, and all other modules touched by this refactor.

---

## 4. C-Line: Chinese Experience (Critical Path)

### C1: ModelManager — Default Engine Switch

**Module**: `DavyWhisper/Services/ModelManagerService.swift`

**Current behavior**: `selectedProviderId` is loaded from `UserDefaults.standard.string(forKey: providerKey)`. On fresh install, this returns `nil` — no engine is selected. The user must manually pick one.

**TDD approach**: Write tests asserting default engine selection logic first, then add Paraformer as the hardcoded fallback.

**Changes**:
- Add a fallback in `ModelManagerService.init()`: when `selectedProviderId` is nil (fresh install), set it to `"paraformer"` and persist to UserDefaults
- Add a constant `static let defaultProviderId = "paraformer"` to `ModelManagerService`
- Ensure engine selection persists across app restarts via UserDefaults (already works)
- WhisperKit (`"whisper"`) remains available as a manual option for English/translation

### C2: ProfileService — Forced Migration

**Module**: `DavyWhisper/Services/ProfileService.swift`

**TDD approach**: Write tests for migration logic first (detect old WhisperKit override → migrate to Paraformer → notify user).

**Changes**:
- On first launch after upgrade, scan all profiles with `engineOverride == "whisper"` (the actual `providerId` for WhisperKit, not "WhisperKit")
- Migrate those overrides to `"paraformer"`
- Show a one-time notification to the user explaining the engine change
- Preserve all other profile settings (language, prompts, etc.)
- Migration runs once, guarded by a `UserDefaults` flag (e.g., `didMigrateDefaultEngine_v1`)

### C3: Model Bundling — Bundle-First Strategy

**Module**: `Plugins/ParaformerPlugin/ParaformerPlugin.swift`, `Plugins/ParaformerPlugin/SherpaOnnx.swift`

**Changes**:
- Model files already exist at `DavyWhisper/Resources/ParaformerModel/` (79MB ASR + 72MB punctuation = 151MB)
- Implement Bundle-first model resolution in `ParaformerPlugin`:
  1. Check user Application Support directory (`~/Library/Application Support/DavyWhisper/PluginData/com.davywhisper.paraformer/`) for downloaded/updated model
  2. If not found, fall back to `Bundle.main.url(forResource: "ParaformerModel", withExtension: nil)`
  3. User directory model overrides bundled model (allows updates without app reinstall)
- Remove any mandatory download requirement for first launch

### C4: End-to-End Verification

**Acceptance criteria**:
- Fresh install → launch → immediately transcribe Chinese audio → CER < 3%
- No network required for first transcription
- Existing profiles migrated to Paraformer with notification
- WhisperKit still selectable manually

---

## 5. A-Line: Simplification

### A1: Remove WebhookPlugin from plugins.json

**Scope**: WebhookPlugin has no source directory in `Plugins/` — it exists only as a downloadable entry in `DavyWhisper/Resources/plugins.json` (lines 71-85, ID: `com.davywhisper.webhook`). There is no WatchFolder plugin entry in `plugins.json` — this was already removed.

**TDD approach**: Write test asserting plugins.json contains no webhook entry after cleanup. Write test asserting no source code references `com.davywhisper.webhook`.

**Changes**:
- Remove `com.davywhisper.webhook` entry from `plugins.json`
- Grep for any remaining references to webhook plugin in source code and remove
- No Settings UI cleanup needed (WebhookPlugin was never integrated into Settings tabs)

### A2: Delete AudioDucking (After Confirmation)

**TDD approach**: Grep all references to AudioDucking across the codebase. If no service, view, or user-facing setting references it, delete with full cleanup.

**Confirmation required**: Verify no user-facing settings or internal services depend on AudioDucking before deletion.

### A3: LLM Unification — Merge Downloadable LLM Plugins into OpenAICompatiblePlugin

**Scope**: GLM, Kimi, and MiniMax LLM plugins exist only as downloadable entries in `plugins.json` — they have **no source directories** under `Plugins/`. The work is: (1) remove their `plugins.json` entries, (2) add built-in presets to the existing `Plugins/OpenAICompatiblePlugin/`, (3) migrate user API key configs.

**Module**: `Plugins/OpenAICompatiblePlugin/OpenAICompatiblePlugin.swift`

**TDD approach**: Write tests for preset selection, API URL construction, and API key retrieval per preset.

**Changes**:
- Add built-in LLM presets to `OpenAICompatiblePlugin`:

  | Preset | Plugin ID (old) | Base URL | API Key Storage |
  |--------|-----------------|----------|----------------|
  | GLM (Zhipu AI) | `com.davywhisper.glm` | `open.bigmodel.cn/api/paas/v4` | Keychain |
  | Kimi (Moonshot) | `com.davywhisper.kimi` | `api.moonshot.cn/v1` | Keychain |
  | MiniMax | `com.davywhisper.minimax` | `api.minimax.chat/v1` | Keychain |

- Remove entries for `com.davywhisper.glm`, `com.davywhisper.kimi`, `com.davywhisper.minimax` from `plugins.json`
- Preserve existing keychain entries for each provider (users don't need to re-enter API keys)
- Add "Custom OpenAI Compatible" option for any other provider (base URL + model name)
- Update Settings UI to show unified provider selector with preset dropdown

### A4: Settings Tab Merge — Already Complete

Settings tabs were already merged from 14 to 9 in an earlier phase. Current tabs (verified from `SettingsView.swift`):

`general, recording, fileTranscription, history, dictionary, profiles, prompts, integrations, advanced`

**No additional work needed.** This step is marked as complete.

---

## 6. B-Line: Test Coverage (CI Gate)

### Baseline Measurement

Before any refactoring begins:
1. Run `xcodebuild test -project DavyWhisper.xcodeproj -scheme DavyWhisper -enableCodeCoverage YES`
2. Extract real coverage numbers per module
3. Document baseline in this spec

### Coverage Targets

**Baseline**: Must be measured before refactoring starts using `xcodebuild test -enableCodeCoverage YES`. Estimated current coverage per testing-framework-design.md: ~8% overall, ~29% Services, ~22% ViewModels.

| Module | Current (est.) | Target |
|--------|----------------|--------|
| ModelManagerService | ~10% | >=80% |
| ProfileService | ~40% | >=80% |
| HTTPServer/Handlers | ~40% | >=85% |
| AudioRecordingService | ~5% | >=70% |
| PluginManager | ~15% | >=75% |
| DictationViewModel | ~10% | >=80% |
| PromptProcessingService | ~20% | >=80% |
| SettingsViewModel | ~10% | >=80% |
| Overall | ~8-9% | >=75% |

### CI Gate Rule

Every PR must achieve >=75% overall coverage before merge. This is enforced by:
- Running `xcodebuild test -enableCodeCoverage YES` in CI
- Parsing coverage report
- Blocking merge if threshold not met

### Test Infrastructure

Existing test infrastructure is sufficient:
- `TestServiceContainer` for dependency injection
- Mock implementations in `DavyWhisperTests/Mocks/`
- Protocol definitions in `DavyWhisper/Protocols/`
- `UserDefaultsProviding` protocol for test isolation

---

## 7. Version Strategy

Version number will be decided after C-line completes and real behavioral differences are measured. Options:

- **1.x.z**: If changes are transparent to users (same API, enhanced defaults)
- **2.0.0-pre**: If breaking changes to HTTP API or plugin interface occur
- **1.x "zh-enhanced"**: Labeled build for Chinese market distribution

Decision deferred to post-C-line evaluation.

---

## 8. Data Migration

| Data Type | Migration Strategy |
|-----------|-------------------|
| Profile engine overrides | Force-migrate `engineOverride == "whisper"` → `"paraformer"`, notify user |
| Plugin-specific settings | Direct delete (WebhookPlugin has no persistent user data) |
| LLM provider selections | Map old plugin IDs to new unified preset IDs (see mapping below) |
| History | Unchanged (engine name in history records is informational only) |
| Dictionary/Snippets | Unchanged |

**LLM Plugin ID Migration Map**:

| Old Plugin ID | New Preset Key | API Key Location |
|---------------|---------------|-----------------|
| `com.davywhisper.glm` | `glm` (preset in OpenAICompatiblePlugin) | Keychain — preserve existing key |
| `com.davywhisper.kimi` | `kimi` (preset in OpenAICompatiblePlugin) | Keychain — preserve existing key |
| `com.davywhisper.minimax` | `minimax` (preset in OpenAICompatiblePlugin) | Keychain — preserve existing key |

---

## 9. Risk Matrix

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Paraformer 151MB bundle increases download size | High | Medium | GitHub Releases have no size limit; acceptable trade-off for Chinese users |
| Profile migration breaks user workflows | Low | High | Write migration tests first; show notification with undo option |
| LLM unification breaks existing API key configs | Medium | Medium | Preserve keychain entries; map old plugin IDs to new preset keys |
| Test coverage gate blocks PR velocity | Medium | Medium | Start with baseline; incrementally raise threshold |
| Bundle-first model resolution picks wrong model | Low | High | Write tests for resolution order (user dir > bundle); add logging |

---

## 10. Success Criteria

1. **Chinese ASR**: Fresh install transcribes Chinese audio with CER < 3%, no download required
2. **Default engine**: Paraformer is auto-selected on fresh install (no nil state)
3. **Plugin registry cleanup**: WebhookPlugin + 3 separate LLM plugins removed from plugins.json
4. **LLM unification**: OpenAICompatiblePlugin handles GLM/Kimi/MiniMax via presets
5. **Test coverage**: >=75% overall, CI-gated
6. **All existing tests**: ~330+ tests continue to pass
7. **HTTP API**: All `/v1/*` endpoints unchanged and passing
8. **No regressions**: Profiles (migrated), history, dictionary, snippets all functional

---

## Appendix A: File Impact Estimate

### C-Line Files

| File | Change Type |
|------|------------|
| `DavyWhisper/Services/ModelManagerService.swift` | Add defaultProviderId fallback |
| `DavyWhisper/Services/ProfileService.swift` | Add migration logic for engine overrides |
| `Plugins/ParaformerPlugin/ParaformerPlugin.swift` | Add Bundle-first model resolution |
| `DavyWhisper/Resources/ParaformerModel/` | Already contains bundled models |
| `DavyWhisperTests/` | New tests for default engine + migration |

### A-Line Files

| File | Change Type |
|------|------------|
| `DavyWhisper/Resources/plugins.json` | Remove webhook + LLM plugin entries |
| `Plugins/OpenAICompatiblePlugin/OpenAICompatiblePlugin.swift` | Add GLM/Kimi/MiniMax presets |
| `DavyWhisper/ViewModels/SettingsViewModel.swift` | Update provider selector |
| `DavyWhisperTests/` | Tests for preset selection + migration |

### B-Line Files

| File | Change Type |
|------|------------|
| `DavyWhisperTests/` | Expand with new test files |
| `.github/workflows/` | Add coverage gate to CI |

## Appendix B: Existing Specs Referenced

| Spec | Path | Relevance |
|------|------|-----------|
| DavyWhisper Design | `docs/superpowers/specs/2026-03-31-davywhisper-design.md` | Original fork spec |
| Testing Framework | `docs/superpowers/specs/2026-04-03-testing-framework-design.md` | Test infrastructure |
| Simplification Plan v2 | `docs/simplification-plan-v2.md` | A-line source |
| Paraformer Integration | `docs/paraformer-integration-plan.md` | C-line source |
| Model Integration | `docs/model-integration-plan.md` | Model bundling |
| Consolidated Optimization | `docs/consolidated-optimization-plan.md` | Combined plan |
