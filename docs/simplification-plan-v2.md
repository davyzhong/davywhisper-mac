# DavyWhisper 功能精简方案

> 日期：2026-04-03
> 状态：Draft · 待用户审批
> 范围：中度精简 — 合并/删除 30-40% 长尾功能

---

## 1. 背景

DavyWhisper 当前 35,358 行 Swift 代码，144 个文件，14 个设置 Tab，11 个插件。核心使用路径（录音→转写→后处理→插入文本）只占 ~40% 代码，其余为长尾功能和过度抽象。

**精简目标**：减少维护负担，降低新用户认知成本，保留全部核心能力。

---

## 2. 精简方案总览

| 方向 | 动作 | 预计减少 |
|------|------|----------|
| A. LLM 插件统一 | 4 个独立 LLM 插件 → 1 个通用 OpenAICompatiblePlugin | ~900 行 |
| B. 砍低价值模块 | WebhookPlugin + WatchFolder + SpeechFeedback + AudioDucking | ~1,030 行 |
| C. 设置 Tab 合并 | 14 Tab → 9 Tab | 代码不变，体验改善 |
| D. 砍零实现协议 | PostProcessor/Action/MemoryStorage 三种空协议 | ~200 行 SDK |
| **合计** | | **~2,130 行 (6%)** |

---

## 3. 方向 A：LLM 插件统一

### 现状
- GLMPlugin (327 行) — 智谱 ChatGLM
- KimiPlugin (303 行) — Moonshot Kimi
- MiniMaxPlugin (299 行) — MiniMax
- QwenLLMPlugin (247 行) — 通义千问

四个插件结构几乎相同：都是 HTTP POST + OpenAI 兼容 `/v1/chat/completions`，仅在 BaseURL 和少量参数上有差异。

### 方案

**删除** 4 个独立插件目录：
```
Plugins/GLMPlugin/     → 删除
Plugins/KimiPlugin/    → 删除
Plugins/MiniMaxPlugin/ → 删除
Plugins/QwenLLMPlugin/ → 删除
```

**新建** 通用 OpenAI Compatible LLM 插件：
```
Plugins/OpenAICompatiblePlugin/
├── OpenAICompatiblePlugin.swift    (~250 行)
├── ProviderPresets.swift           (~80 行)
└── manifest_OpenAICompatiblePlugin.json
```

**ProviderPresets.swift** 预置国内主流提供商配置：
```swift
static let presets: [ProviderPreset] = [
    .init(name: "智谱 GLM",  baseURL: "https://open.bigmodel.cn/api/paas", model: "glm-4-flash"),
    .init(name: "Moonshot",   baseURL: "https://api.moonshot.cn/v1",        model: "moonshot-v1-8k"),
    .init(name: "MiniMax",    baseURL: "https://api.minimax.chat/v1",        model: "MiniMax-Text-01"),
    .init(name: "通义千问",    baseURL: "https://dashscope.aliyuncs.com/compatible-mode/v1", model: "qwen-turbo"),
    .init(name: "DeepSeek",   baseURL: "https://api.deepseek.com/v1",       model: "deepseek-chat"),
    .init(name: "自定义",      baseURL: "",                                   model: ""),
]
```

**用户体验变化**：
- 设置界面从 "选择 GLM/Kimi/MiniMax/QwenLLM" 变为 "选择预设提供商 → 填 API Key"
- 支持自定义 BaseURL，覆盖所有 OpenAI 兼容 API
- 每个 preset 可以记住独立的 API Key

**影响范围**：
- `PluginManager.swift` — 从 pluginNames 中移除 4 个旧名称，加入 OpenAICompatiblePlugin
- `PromptProcessingService.swift` — 无需改动，LLMProviderPlugin 接口不变
- `SettingsView` 插件列表 — 自动适配（读 manifest）

---

## 4. 方向 B：砍低价值模块

### B1. WebhookPlugin（474 行）

**理由**：示例/参考插件，实际使用率极低。HTTP API Server 已提供同等能力。

**动作**：
- 删除 `Plugins/WebhookPlugin/` 整个目录
- 从 `project.yml` 的 sources 中移除
- 从 `PluginManager.pluginNames` 中移除

### B2. WatchFolder（~480 行）

**理由**：文件夹自动监视转写是极少数用户配置的功能，FileTranscriptionView 的手动拖放覆盖了相同场景。

**动作**：
- 删除 `DavyWhisper/Services/WatchFolderService.swift`（314 行）
- 删除 `DavyWhisper/ViewModels/WatchFolderViewModel.swift`（164 行）
- 从 AdvancedSettingsView 中移除 WatchFolder 相关 UI
- 从 project.yml / pbxproj 中清理引用

### B3. SpeechFeedbackService（83 行）

**理由**：TTS 语音反馈极少用户开启。录音提示音（SoundService）保留，TTS 语音播报"已开始录音"类功能砍掉。

**动作**：
- 删除 `DavyWhisper/Services/SpeechFeedbackService.swift`
- 从 DictationViewModel 中移除对 SpeechFeedbackService 的调用

### B4. AudioDuckingService（100 行）

**理由**：录音时自动降低系统音量是小众需求。用户可在系统设置中自行配置。

**动作**：
- 删除 `DavyWhisper/Services/AudioDuckingService.swift`
- 从 DictationViewModel 中移除 ducking 调用

---

## 5. 方向 C：设置 Tab 合并（14 → 9）

### 合并方案

| 新 Tab | 合并内容 | 变化 |
|--------|----------|------|
| 通用 | General（不变） | — |
| 录音 | Recording + Hotkeys 合并 | 2→1 |
| 文件转写 | File Transcription（不变） | — |
| 词典 | Dictionary + Snippets 合并为「词典 & 片段」 | 2→1 |
| 历史 | History（不变） | — |
| 配置档案 | Profiles（不变） | — |
| Prompts | Prompts（不变） | — |
| 插件 | Integrations/PluginSettings（不变） | — |
| 高级 | Advanced 合并 About + 移除已砍功能 | 精简 |

**砍掉的 Tab**：
- ~~Home（仪表盘）~~ — 使用频率最低的 Tab，统计信息可在 About 中简要展示
- ~~Audio Recorder（独立录音器）~~ — 极少用户使用，与主录音功能重叠
- ~~WatchFolder~~ — 模块已砍

**净减少**：14 → 9 Tab（减少 5 个）

---

## 6. 方向 D：砍零实现插件协议

### 现状
PluginSDK 中定义了 3 种零实现的插件协议：
- `PostProcessorPlugin` — 文本后处理器
- `ActionPlugin` — 动作执行
- `MemoryStoragePlugin` — 记忆存储

### 动作
- 从 `TypeWhisperPlugin.swift` 中删除这 3 个协议定义（~120 行）
- 从 `HostServices.swift` 中删除相关的宿主服务方法
- 从 `PluginManager.swift` 中删除 `postProcessors`、`actionPlugins`、`memoryStoragePlugins` 三个计算属性
- 从 `TypeWhisperEvent.swift` 中删除相关事件定义
- 保留：`DavyWhisperPlugin`（基础）、`TranscriptionEnginePlugin`（转写）、`LLMProviderPlugin`（LLM）——这 3 个有实际实现

---

## 7. 不动的部分

以下核心能力**不砍不合并**：

| 模块 | 理由 |
|------|------|
| WhisperKitPlugin | 核心转写引擎 |
| ParaformerPlugin | 中文 ASR 核心差异化 |
| DeepgramPlugin | 云端实时转写 |
| ElevenLabsPlugin | 国际市场云端转写 |
| Qwen3Plugin | 通义千问音频理解 |
| LiveTranscriptPlugin | 实时字幕核心功能 |
| TranslationService | 翻译是高频需求 |
| DictionaryService | 术语替换是专业用户刚需 |
| ProfileService | 多场景配置是核心差异化 |
| HTTPServer/API | 开发者 API 是重要特性 |
| CLI 工具 | 开发者集成入口 |
| 全部指示器（Notch/Overlay） | 视觉反馈核心 |
| SetupWizardView | 首次体验重要 |
| HistoryService | 历史记录是基础功能 |
| MemoryService | 从转写提取记忆，与 LLM 联动 |

---

## 8. 预期效果

| 指标 | 精简前 | 精简后 | 变化 |
|------|--------|--------|------|
| Swift 代码行数 | 35,358 | ~33,200 | -6% |
| 设置 Tab | 14 | 9 | -36% |
| 插件数量 | 11 | 6 | -45% |
| LLM 提供商支持 | 4 独立插件 | 1 通用 + 5 预设 | 维护成本 -75% |
| Services 文件 | 42 | 39 | -7% |
| 插件协议类型 | 6 (3 零实现) | 3 (全部有实现) | -50% |

---

## 9. 执行顺序

| Phase | 内容 | 风险 | 状态 |
|-------|------|------|------|
| Phase 1 | 方向 B：砍低价值模块（WebhookPlugin + WatchFolder + SpeechFeedback + AudioDucking） | 低 | ✅ 完成 |
| Phase 2 | 方向 D：砍零实现协议（SDK 层清理） | 低 | 待执行 |
| Phase 3 | 方向 A：LLM 插件统一（核心变更） | 中 | 待执行 |
| Phase 4 | 方向 C：设置 Tab 合并（UI 层调整） | 低 | 待执行 |

每个 Phase 完成后：build 验证 → commit → push → 进入下一 Phase。

---

## 10. 风险评估

| 风险 | 概率 | 应对 |
|------|------|------|
| 用户正在使用被砍的 LLM 插件 | 低 | OpenAICompatiblePlugin 预置相同提供商，迁移成本低 |
| 砍 WatchFolder 影响自动化工作流 | 低 | HTTP API + CLI 提供同等自动化能力 |
| 砍协议导致第三方插件不兼容 | 低 | 当前无第三方插件生态 |
| 合并 Tab 导致用户找不到设置 | 中 | 保持 Tab 名称语义清晰 |
