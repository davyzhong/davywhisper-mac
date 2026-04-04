# DavyWhisper v1.x Refactoring Design

**Date:** 2026-04-04
**Status:** Draft
**Author:** Claude Code (brainstorming session with user)

---

## 1. Background

DavyWhisper is a macOS menu bar speech-to-text app forked from TypeWhisper (German → Simplified Chinese). The fork phases 1-6 are complete (brand, feature trimming, LLM providers, localization, China mirror, finishing). The codebase sits at:

- **35,358 lines** Swift across **144 files**
- **97 main app** Swift files, **36 services**, **14 ViewModels**, **30 views**
- **7 plugins**: WhisperKit, Deepgram, ElevenLabs, Paraformer, Qwen3, OpenAICompatible, LiveTranscript
- **355 unit tests** passing, ~25% coverage
- **14 Settings tabs**

Three critical gaps exist:

1. **Chinese ASR accuracy**: Paraformer plugin exists in code but is not the default engine. WhisperKit (~8-10% CER on Chinese) is still the default. Target: ~2-3% CER.
2. **Code bloat**: WebhookPlugin, WatchFolder, and separate LLM plugins increase maintenance burden without proportional value for Chinese users.
3. **Test coverage**: 25% is far below the 75% stability contract target.

---

## 2. Goals

| Dimension | Current | Target |
|-----------|---------|--------|
| Chinese ASR accuracy | ~8-10% CER (WhisperKit base) | ~2-3% CER (Paraformer) |
| Out-of-box usability | Requires model download | Works immediately (151MB bundled) |
| Default engine | WhisperKit | Paraformer |
| Plugin count | 7 | 4 (remove Webhook, WatchFolder; merge LLMs) |
| LLM plugins | 4 separate | 1 unified OpenAICompatiblePlugin |
| Settings tabs | 14 | 9 |
| Test coverage | ~25% | >=75% (CI gate) |
| Swift LOC | ~35,358 | ~33,200 (-6%) |

---

## 3. Execution Model

**P9 Tech Lead orchestrator** manages three workstreams. Key path sequencing: C-line runs first as the critical path, then A-line and B-line run in parallel.

```
Baseline: Measure current test coverage
    |
C-line (Critical Path) ──┐
    |                     ├── After C-line completes:
A-line (Simplification) ──┤    Run full coverage gate
    |                     │
B-line (Testing) ─────────┘
```

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

**Module**: `ModelManagerService.swift`

**TDD approach**: Write tests asserting default engine selection logic first, then change the default from WhisperKit to Paraformer.

**Changes**:
- Change the global default transcription engine from WhisperKit to Paraformer
- Ensure engine selection persists across app restarts via UserDefaults
- When no user preference exists, Paraformer is selected automatically
- WhisperKit remains available as a manual option for English/translation use cases

### C2: ProfileService — Forced Migration

**Module**: `ProfileService.swift`

**TDD approach**: Write tests for migration logic first (detect old WhisperKit override → migrate to Paraformer → notify user).

**Changes**:
- On first launch after upgrade, scan all profiles with `engineOverride == "WhisperKit"`
- Migrate those overrides to `"Paraformer"`
- Show a one-time notification to the user explaining the engine change
- Preserve any other profile settings (language, prompts, etc.)

### C3: Model Bundling — Bundle-First Strategy

**Module**: `ParaformerPlugin.swift`, `SherpaOnnx.swift`

**Changes**:
- Bundle Paraformer model (79MB) + Punctuation model (72MB) = 151MB into `Resources/ParaformerModel/`
- Already partially done — model files exist at this path
- Implement Bundle-first model resolution:
  1. Check `Bundle.main.url(forResource:)` for bundled model
  2. Check user Application Support directory for downloaded/updated model
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

### A1: Delete WebhookPlugin + WatchFolder (Low Risk, Run First)

**TDD approach**: Write deletion verification tests — assert that removed code has no remaining references, no dangling imports, no orphaned Settings entries.

**What to delete (full cleanup)**:
- Plugin source files and manifests
- Any ViewModel/Service/View that exists solely for these plugins
- Settings UI tabs/sections pointing to these plugins
- UserDefaults keys specific to these plugins
- Test files for these plugins

**Execution order**: WebhookPlugin first (zero user-facing impact), then WatchFolder.

### A2: Delete AudioDucking (After Confirmation)

**TDD approach**: Grep all references to AudioDucking across the codebase. If no service, view, or user-facing setting references it, delete with full cleanup.

**Confirmation required**: Verify no user-facing settings or internal services depend on AudioDucking before deletion.

### A3: LLM Unification — 4-in-1 OpenAICompatiblePlugin

**Module**: `OpenAICompatiblePlugin.swift`

**TDD approach**: Write comprehensive tests for the unified plugin first — test each preset (GLM, Kimi, Moonshot, MiniMax) + custom URL, then implement.

**Changes**:
- Merge GLM, Kimi, MiniMax, QwenLLM plugins into a single `OpenAICompatiblePlugin`
- Built-in presets:
  | Preset | Base URL | Auth |
  |--------|----------|------|
  | GLM (Zhipu AI) | `open.bigmodel.cn/api/paas/v4` | API key |
  | Kimi (Moonshot) | `api.moonshot.cn/v1` | API key |
  | MiniMax | `api.minimax.chat/v1` | API key |
  | Moonshot | `api.moonshot.cn/v1` | API key |
- Users can add custom providers via base URL + model name
- Delete 4 separate plugin directories after merge
- Update `project.yml` to remove old plugin targets
- Update Settings UI to show unified provider selector

### A4: Settings Tab Merge (14 → 9)

**Merge plan**:

| Before (14) | After (9) | Merge Logic |
|-------------|-----------|-------------|
| General | General | Unchanged |
| Recording | Input | Recording + Hotkeys merged |
| Hotkeys | (merged into Input) | |
| Profiles | Profiles | Unchanged |
| Plugins | Plugins | Unchanged |
| Dictionary | Words | Dictionary + Snippets merged |
| Snippets | (merged into Words) | |
| Prompts | Prompts | Unchanged |
| Advanced | System | Advanced + API Server merged |
| API Server | (merged into System) | |
| History | History | Unchanged |
| Translation | Translation | Unchanged |
| About | About | Unchanged |
| Error Log | (merged into System) | Merged into System tab |

**TDD approach**: Write UI tests for each merged tab to verify navigation and content rendering before merging.

---

## 6. B-Line: Test Coverage (CI Gate)

### Baseline Measurement

Before any refactoring begins:
1. Run `xcodebuild test -project DavyWhisper.xcodeproj -scheme DavyWhisper -enableCodeCoverage YES`
2. Extract real coverage numbers per module
3. Document baseline in this spec

### Coverage Targets

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
| Overall | ~25% | >=75% |

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
| Profile engine overrides | Force-migrate WhisperKit → Paraformer, notify user |
| Plugin-specific settings | Direct delete (WebhookPlugin, WatchFolder have no persistent user data) |
| LLM provider selections | Map old plugin IDs to new unified plugin preset IDs |
| History | Unchanged (engine name in history records is informational only) |
| Dictionary/Snippets | Unchanged |

---

## 9. Risk Matrix

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Paraformer model too large (151MB) for App Store | Medium | High | Verify App Store size limits; consider on-demand download as fallback |
| Profile migration breaks user workflows | Low | High | Write migration tests first; show notification with undo option |
| LLM unification breaks existing API key configs | Medium | Medium | Map old plugin IDs to new preset IDs; preserve keychain entries |
| Test coverage gate blocks PR velocity | Medium | Medium | Start with baseline; incrementally raise threshold |
| Settings tab merge confuses existing users | Low | Low | Keep tab names descriptive; no functionality removed |

---

## 10. Success Criteria

1. **Chinese ASR**: Fresh install transcribes Chinese audio with CER < 3%, no download required
2. **Code reduction**: ~2,100 lines removed (6% reduction)
3. **Plugin count**: 7 → 4
4. **Settings tabs**: 14 → 9
5. **Test coverage**: >=75% overall, CI-gated
6. **All existing tests**: 355+ tests continue to pass
7. **HTTP API**: All `/v1/*` endpoints unchanged and passing
8. **No regressions**: Profiles, history, dictionary, snippets all functional

---

## Appendix A: File Impact Estimate

### C-Line Files

| File | Change Type |
|------|------------|
| `Services/ModelManagerService.swift` | Modify default engine |
| `Services/ProfileService.swift` | Add migration logic |
| `Plugins/ParaformerPlugin/ParaformerPlugin.swift` | Modify model path resolution |
| `Plugins/ParaformerPlugin/SherpaOnnx.swift` | Possibly update |
| `ViewModels/SettingsViewModel.swift` | Update engine selector UI |
| `Resources/ParaformerModel/` | Already contains models |
| `DavyWhisperTests/` | New tests for migration + default engine |

### A-Line Files

| File | Change Type |
|------|------------|
| `Plugins/WebhookPlugin/` | Delete entirely |
| `Plugins/WatchFolder/` | Delete entirely |
| `Services/AudioDucking*` | Delete (after confirmation) |
| `Plugins/GLMPlugin/` | Delete (merged into OpenAICompatible) |
| `Plugins/KimiPlugin/` | Delete (merged into OpenAICompatible) |
| `Plugins/MiniMaxPlugin/` | Delete (merged into OpenAICompatible) |
| `Plugins/QwenLLMPlugin/` | Delete (merged into OpenAICompatible) |
| `Plugins/OpenAICompatiblePlugin/` | Expand with presets |
| `Views/SettingsView.swift` | Modify tab structure |
| `Views/*SettingsView.swift` | Merge related views |
| `project.yml` | Remove deleted plugin targets |

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
