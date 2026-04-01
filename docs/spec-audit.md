# DavyWhisper Spec vs Implementation Audit

> Generated: 2026-04-01
> Based on: `docs/superpowers/specs/2026-03-31-davywhisper-design.md`

---

## Legend

- ✅ Done
- 🔶 Partial
- ❌ Not done
- ⚠️ Ghost (deleted from disk, pbxproj still references)

---

## Phase 1: Brand Skeleton

| # | Spec Requirement | Status | Details |
|---|-----------------|--------|---------|
| 1.1 | Fork code to new directory | ✅ | `DavyWhisper/` from `TypeWhisper/` |
| 1.2 | Global rename: TypeWhisper → DavyWhisper in source | ✅ | All Swift source files renamed |
| 1.3 | Bundle ID: com.typewhisper → com.davywhisper | ❌ | 100+ lines in pbxproj still `com.typewhisper.*`. xcconfig: `APP_GROUP_ID = ...com.typewhisper.mac`. Built app: `CFBundleIdentifier = com.typewhisper.mac` |
| 1.4 | App Icon replaced | ✅ | All 10 PNG sizes replaced |
| 1.5 | Build passes | ✅ | Debug build confirmed working |

## Phase 2: Feature Trimming

| # | Spec Requirement | Status | Details |
|---|-----------------|--------|---------|
| 2.1 | Remove Widget Extension target | 🔶 | Dirs deleted, but **pbxproj still has widget target `DD00000000000000000014`** with build configs + Embed App Extensions phase |
| 2.2 | Delete WidgetDataService.swift | ❌ | **`DavyWhisper/Services/WidgetDataService.swift` still exists** — dead code with `import WidgetKit` |
| 2.3 | Delete 20 plugin directories | ✅ | All deleted from disk |
| 2.4 | Remove Sparkle SPM dependency | 🔶 | Source code clean (UpdateChecker.swift deleted). But **pbxproj still has** `RR00000000000000000004 /* XCRemoteSwiftPackageReference "Sparkle" */` and **Info.plist still has** `SUFeedURL` + `SUPublicEDKey` |
| 2.5 | Remove "Check for Updates" UI | ✅ | No Sparkle references in GeneralSettingsView or AdvancedSettingsView |
| 2.6 | Build passes after trimming | ✅ | Debug build works |

## Phase 3: New LLM Providers

| # | Spec Requirement | Status | Details |
|---|-----------------|--------|---------|
| 3.1 | GLMPlugin (OpenAI-compatible) | ✅ | `Plugins/GLMPlugin/` exists, 327 lines |
| 3.2 | KimiPlugin (OpenAI-compatible) | ✅ | `Plugins/KimiPlugin/` exists, 303 lines |
| 3.3 | MiniMaxPlugin (custom adapter) | ✅ | `Plugins/MiniMaxPlugin/` exists, 299 lines, custom MiniMaxChatAdapter |
| 3.4 | Plugins can register/configure/save API Key | 🔶 | Source code exists, but **not built by main Xcode project**. Built via Run Script phase from `DavyWhisperPlugins.xcodeproj` |

## Phase 4: Localization

| # | Spec Requirement | Status | Details |
|---|-----------------|--------|---------|
| 4.1 | Main app Localizable.xcstrings: de → zh-Hans | ✅ | zh-Hans entries present |
| 4.2 | GeneralSettingsView language selector: zh-Hans | ✅ | `Text("简体中文").tag("zh-Hans")` |
| 4.3 | WhisperKitPlugin Localizable.xcstrings | ✅ | zh-Hans |
| 4.4 | DeepgramPlugin Localizable.xcstrings | ❌ | Still **de**, not zh-Hans |
| 4.5 | WebhookPlugin Localizable.xcstrings | ❌ | Still **de**, not zh-Hans |
| 4.6 | ElevenLabsPlugin Localizable.xcstrings | ❌ | Still **de**, not zh-Hans |
| 4.7 | Qwen3Plugin Localizable.xcstrings | ✅ | zh-Hans |
| 4.8 | LiveTranscriptPlugin Localizable.xcstrings | 🔶 | Not verified, likely still de |
| 4.9 | GLM/Kimi/MiniMaxPlugin Localizable.xcstrings | ✅ | zh-Hans (new plugins, created fresh) |
| 4.10 | Info.plist CFBundleLocalizations: de → zh-Hans | ❌ | Still lists **de** |

## Phase 5: China Mirror

| # | Spec Requirement | Status | Details |
|---|-----------------|--------|---------|
| 5.1 | HF_ENDPOINT in main.swift | ✅ | `setenv("HF_ENDPOINT", "https://hf-mirror.com", 1)` |
| 5.2 | Mirror toggle in AdvancedSettingsView | ✅ | Toggle UI exists |
| 5.3 | UserDefaultsKeys.useHuggingFaceMirror | ✅ | Key defined |

## Phase 6: Finishing

| # | Spec Requirement | Status | Details |
|---|-----------------|--------|---------|
| 6.1 | HTTP API path /v1/ unchanged | ✅ | No changes needed |
| 6.2 | CLI tool renamed to davywhisper-cli | ✅ | Directory + source renamed |
| 6.3 | Homebrew Cask renamed to davywhisper | ❌ | Not done |
| 6.4 | Final build + DMG output | 🔶 | Build works, DMG script updated |

---

## pbxproj Specific Issues

### Ghost Targets (source deleted, target remains)

| Target | ID | Impact |
|--------|-----|--------|
| typewhisper-cli | `DD00000000000000000002` | Builds a dead target; has CopyFiles phase, 4 build configs, ContainerItemProxy, TargetDependency |
| CerebrasPlugin | `DD00000000000000000026` | Builds a non-existent plugin; has Sources/Frameworks/Resources phases + 4 build configs |
| GladiaPlugin | `DD00000000000000000029` | Same as above |
| DavyWhisperWidgetExtension | `DD00000000000000000014` | Has full target + Embed App Extensions phase referencing `.appex` |

### Plugins Built But NOT Embedded

| Plugin | Has Target in pbxproj | In Embed PlugIns Phase | Result |
|--------|----------------------|----------------------|--------|
| WhisperKitPlugin | ✅ | ✅ | Embedded |
| DeepgramPlugin | ✅ | ✅ | Embedded |
| LiveTranscriptPlugin | ✅ | ✅ | Embedded |
| WebhookPlugin | ✅ | ❌ | **Built but NOT in app bundle** |
| ElevenLabsPlugin | ✅ | ❌ | **Built but NOT in app bundle** |
| Qwen3Plugin | ❌ | ❌ | **No target in main project** |
| GLM/Kimi/MiniMax/QwenLLM | ❌ (separate xcodeproj) | ❌ | Built by Run Script, copied manually |

---

## Summary Counts

| Category | Count |
|----------|-------|
| ✅ Fully done | 17 |
| 🔶 Partially done | 5 |
| ❌ Not done | 8 |

---

## Priority Ranking

### P0 — Build/Plugin Loading

1. **Remove ghost targets from pbxproj** — typewhisper-cli, CerebrasPlugin, GladiaPlugin, DavyWhisperWidgetExtension (4 targets with ~80 references total)
2. **Embed WebhookPlugin + ElevenLabsPlugin** — Add to Embed PlugIns build phase
3. **Add Qwen3Plugin target to main project** — Currently missing entirely

### P1 — Brand Identity

4. **Bundle ID rename**: com.typewhisper → com.davywhisper in pbxproj (100+ lines), xcconfig, entitlements
5. **Remove Sparkle from pbxproj** — Package reference + Info.plist SUFeedURL/SUPublicEDKey
6. **Delete WidgetDataService.swift** — Dead code
7. **Remove Widget Embed App Extensions phase** from pbxproj

### P2 — Localization

8. **Convert 3 plugin Localizable.xcstrings**: DeepgramPlugin, WebhookPlugin, ElevenLabsPlugin (de → zh-Hans)
9. **Update Info.plist CFBundleLocalizations**: de → zh-Hans
10. **Verify LiveTranscriptPlugin** Localizable.xcstrings

### P3 — Polish

11. Rename pbxproj CLI target from `typewhisper-cli` → `davywhisper-cli`
12. Human localization review (P0/P1 strings)
13. Homebrew Cask setup
