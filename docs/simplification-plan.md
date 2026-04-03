# DavyWhisper 功能精简方案

> 日期：2026-04-02
> 状态：已规划，暂不执行

---

## 一、现状审计数据

### 代码规模

| 维度 | 数量 | 最大文件 |
|------|------|---------|
| Services | 37个 | AudioRecorderService (1069行), HotkeyService (833行), TextInsertionService (594行) |
| Views | 25个 | SetupWizardView (1166行), PluginSettingsView (687行), HistoryView (679行) |
| ViewModels | 12个 | DictationViewModel (984行), AudioRecorderViewModel (455行) |
| Plugins | 10个 | Deepgram (867行), LiveTranscript (687行), WhisperKit (643行) |
| Settings Tab | **9个** | fileTranscription/history/dictionary/snippets/profiles/prompts/integrations/advanced/about |

### 各 Service 体积排行

```
1069  AudioRecorderService.swift
 833  HotkeyService.swift
 594  TextInsertionService.swift
 413  PluginRegistryService.swift
 376  AudioRecordingService.swift
 350  TranslationService.swift
 348  AudioDeviceService.swift
 319  HistoryService.swift
 317  ModelManagerService.swift
 314  WatchFolderService.swift
 306  DictionaryService.swift
 299  PluginManager.swift
 271  MemoryService.swift
 227  ErrorLogService.swift
```

### 各 Plugin 体积排行

```
 867  DeepgramPlugin         — 云端ASR
 687  LiveTranscriptPlugin   — 实时字幕面板
 643  WhisperKitPlugin      — 本地ASR
 613  ElevenLabsPlugin      — TTS（语音合成，跟产品定位不符）
 516  Qwen3Plugin           — MLX依赖不存在，已排除但manifest残留
 474  WebhookPlugin          — Webhook通知，小众
 327  GLMPlugin             — 中文LLM后处理
 303  KimiPlugin            — 中文LLM后处理
 299  MiniMaxPlugin         — 中文LLM后处理
 247  QwenLLMPlugin         — 中文LLM后处理
```

---

## 二、精简方案

### 🔴 直接删除（无争议）

| 功能 | 文件 | 理由 |
|------|------|------|
| **ErrorLogService** | `Services/ErrorLogService.swift` (227行) | 开发者调试功能，普通用户无感知 |
| **ErrorLogView** | `Views/ErrorLogView.swift` (126行) | 配套删除 |
| **WebhookPlugin** | `Plugins/WebhookPlugin/` (474行) | 极小众需求，需外部服务器，国内用户几乎不用 |
| **Qwen3Plugin** | `Plugins/Qwen3Plugin/` (516行) | MLX依赖不存在，project.yml已排除但manifest残留，彻底移除 |
| **ElevenLabsPlugin** | `Plugins/ElevenLabsPlugin/` (613行) | TTS插件，DavyWhisper是语音转文字产品，TTS超出范围 |

**删除后插件从 10 个 → 5 个：**
```
WhisperKit / Deepgram / LiveTranscript / GLM / Kimi / MiniMax / QwenLLM
(删除: Qwen3 / Webhook / ElevenLabs)
```

### 🟡 合并 Settings Tab（9 → 5）

**当前结构（9个Tab）：**
```
fileTranscription / history / dictionary / snippets / profiles / prompts / integrations / advanced / about
```

**建议结构（5个Tab）：**

| 新Tab | 合并来源 | 内容 |
|--------|---------|------|
| **通用 General** | history + dictionary + snippets + fileTranscription | 录音历史、自定义词典、文本片段、文件转写 |
| **引擎 Engines** | （新Tab） | WhisperKit + Paraformer + Deepgram + LiveTranscript 插件配置入口 |
| **后处理 PostProcessing** | profiles + prompts | 应用配置 + LLM提示词模板 |
| **高级 Advanced** | integrations + advanced | API Server、Webhook（删后移除）、WatchFolder、翻译、语言设置 |
| **关于 About** | about | 版本、许可、关于 |

### 🟠 功能降级（保留代码，默认隐藏）

| 功能 | 当前状态 | 建议 | 理由 |
|------|---------|------|------|
| **TranslationService** | 始终加载 | 按需初始化 | 依赖 `macOS 15+`，macOS 14用户完全不可用；改为懒加载 |
| **TermPackRegistryService** | 始终加载 | 默认关闭，需用户主动开启 | 从网络获取词包注册表，国内访问困难；默认隐藏设置入口 |
| **WatchFolderService** | 普通功能 | 移入"高级"Tab | 监控文件夹转写，小众需求；非核心流程 |
| **HistoryExporter** | 直接暴露 | 移入历史Tab二级菜单 | 导出功能低频；不需要直接暴露 |
| **MemoryService** | 始终加载 | 默认关闭 | 从转写内容提取"记忆"存外部；验证是否有用户使用后再决定去留 |

### 🟢 代码重构（不删功能，降低复杂度）

| 问题文件 | 当前行数 | 重构目标 |
|---------|---------|---------|
| **SetupWizardView** | 1166行 | 拆为 `OnboardingView` + `PermissionSetupView` + `EngineSetupView` |
| **DictationViewModel** | 984行 | 拆为 `RecordingStateManager` + `TranscriptionCoordinator` |
| **PluginSettingsView** | 687行 | 按插件类型分 `TranscriptionEngineSettingsView` / `LLMProviderSettingsView` |

---

## 三、精简目标

| 维度 | 当前 | 精简后 | 减少 |
|------|------|--------|------|
| Plugins | 10个 | **5个** | -50% |
| Settings Tab | 9个 | **5个** | -44% |
| Services | 37个 | **~31个** | -16% |
| 直接删除代码行 | — | **~2000行** | — |
| 需拆分的大文件 | 3个 | **3个** | — |

---

## 四、执行顺序

```
Phase 1: 删除无争议代码（不影响功能）
  ├── 删除 ErrorLogService + ErrorLogView
  ├── 删除 WebhookPlugin
  ├── 删除 Qwen3Plugin
  └── 删除 ElevenLabsPlugin

Phase 2: Settings 重组（影响UI，需验证）
  ├── 合并 Settings Tab 9→5
  └── 移动功能到对应Tab

Phase 3: 功能降级（需验证行为不变）
  ├── TranslationService 改为懒加载
  ├── TermPackRegistry 默认隐藏
  └── WatchFolderService 移入高级Tab

Phase 4: 大文件拆分（代码重构，无功能变更）
  ├── SetupWizardView 拆解
  ├── DictationViewModel 拆解
  └── PluginSettingsView 拆解
```

---

## 五、风险评估

| 精简项 | 风险 | 缓解 |
|--------|------|------|
| 删除 ElevenLabsPlugin | 影响已有配置的用户 | 提前发版公告；迁移路径 |
| 合并 Settings Tab | 用户习惯改变 | 保持快捷键一致；Tab顺序可配置 |
| 删除 ErrorLogService | 开发者调试能力 | CLI 工具补充 `davywhisper-cli logs` |
| 删除 WebhookPlugin | 已有Webhook配置的用户 | 同上，提前公告 |

---

## 六、不精简的部分

以下功能虽然复杂，但作为开发者工具保留：

- **HotkeyService (833行)** — 全局快捷键，核心交互
- **AudioRecorderService (1069行)** — 录音管理，复杂但必需
- **HTTPServer + APIRouter** — 自动化API，核心卖点
- **PluginManager** — 插件架构基础
- **PromptProcessingService** — LLM后处理核心
- **所有 LLM Provider Plugins (GLM/Kimi/MiniMax/QwenLLM)** — 差异化功能
