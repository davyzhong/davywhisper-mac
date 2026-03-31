# DavyWhisper Fork Design Spec

**Date**: 2026-03-31
**Project**: DavyWhisper — DavyWhisper 中文本地化轻量化 Fork
**Version**: 1.0

---

## 1. 概述

### 1.1 背景

DavyWhisper 是一个开源的 macOS 菜单栏语音输入工具，支持 8 个转写引擎和多个 LLM Provider。本项目将其 fork 并进行中文本地化、品牌重塑和功能精简，面向国内 macOS 用户。

### 1.2 目标

将 DavyWhisper fork 为 **DavyWhisper**，定位：面向中文用户的轻量化本地语音输入工具，保留核心差异化能力，去掉对国内用户无效的插件和云服务。

### 1.3 设计原则

- **中文优先**：引擎选择、模型下载、LLM Provider 全部围绕国内可用性设计
- **轻量化**：删除 Widget、Sparkle 自动升级、大部分云端插件
- **品牌独立**：App 名称、图标、Bundle ID 全部重命名，独立分发
- **本地优先**：转写尽量走本地模型，LLM 用国内服务

---

## 2. 功能范围

### 2.1 保留的核心功能

| 功能 | 说明 |
|------|------|
| 全局热键录音 | Push-to-talk、Toggle、Hybrid 三种模式 |
| 文件转写 | 音频/视频文件批量转写 |
| 实时预览 | WhisperKit 流式预览 |
| 中文转写 | Qwen3 本地中文 ASR |
| Prompt 处理 | 自定义 Prompt + LLM 处理（翻译/格式化等） |
| 历史记录 | SwiftData 持久化 |
| 词典 | 自定义术语纠正 |
| HTTP API | 本地 REST API（`/v1/*`） |
| CLI 工具 | 命令行转写 |
| Plugin SDK | 插件系统骨架 |

### 2.2 删除的功能

| 功能 | 原因 |
|------|------|
| Widget 桌面小组件 | 轻量化，与核心功能无关 |
| Sparkle 自动升级 | 用户不需要，简化分发 |
| 大部分云端插件（19个） | 国内不可用或非核心 |
| 德语 UI | 替换为简体中文 |

---

## 3. 插件架构

### 3.1 最终插件清单

| 插件 | 类型 | 用途 | 国内可用性 |
|------|------|------|:---:|
| WhisperKitPlugin | TranscriptionEngine | 本地流式预览（默认 Tiny/Base） | ✅ 本地 |
| Qwen3Plugin | TranscriptionEngine | 本地中文正式转写 | ✅ 本地 |
| LiveTranscriptPlugin | Plugin | 录音时实时显示字幕面板 | ✅ |
| WebhookPlugin | Plugin | 转写结果 HTTP 推送 | ✅ |
| DeepgramPlugin | TranscriptionEngine | 云端 ASR 备选 | ✅ |
| ElevenLabsPlugin | LLMProvider + Action | TTS 语音合成 | ✅ |

### 3.2 新增 LLM Provider

| 插件 | Bundle ID | API Base URL | 模型 |
|------|-----------|-------------|------|
| GLMPlugin | com.davywhisper.glm | https://open.bigmodel.cn | GLM-4, GLM-4 Flash |
| KimiPlugin | com.davywhisper.kimi | https://api.moonshot.cn | moonshot-v1-8k/32k/128k |
| MiniMaxPlugin | com.davywhisper.minimax | https://api.minimaxi.com | abab6-chat, MiniMax-Text-01, M2, M2.1 |

**MiniMax 接入说明**：MiniMax API 不是 OpenAI-compatible 格式，请求体为 `{"sender_type": "USER", "text": "..."}`，响应体为 `{"reply": "..."}`，需要在 `MiniMaxPlugin` 中实现自定义 `MiniMaxChatAdapter`，不能复用 `PluginOpenAIChatHelper`。

**MiniMaxChatAdapter 接口定义**：

```swift
// 请求结构
struct MiniMaxChatRequest: Encodable {
    let model: String
    let messages: [MiniMaxMessage]
    let stream: Bool
    let temperature: Double
    let tokens_to_generate: Int  // 生成 token 上限

    enum CodingKeys: String, CodingKey {
        case model, messages, stream, temperature, tokens_to_generate
    }
}

struct MiniMaxMessage: Encodable {
    let sender_type: String  // "USER" 或 "BOT"
    let sender_name: String?  // 可选
    let text: String
}

// 响应结构（非流式）
struct MiniMaxChatResponse: Decodable {
    let reply: String
}

// 接口方法（需要实现）
protocol MiniMaxChatAdapter {
    func chat(request: MiniMaxChatRequest, apiKey: String, groupId: String) async throws -> String
}
```

请求示例：
```
POST https://api.minimaxi.com/v1/text/chatcompletion_pro?GroupId=<group_id>
Header: Authorization: Bearer <api_key>
Body: { "model": "abab6-chat", "messages": [...], "stream": false, "tokens_to_generate": 1024 }
```

### 3.3 删除的插件

以下 20 个插件目录全部删除：AssemblyAIPlugin, CerebrasPlugin, ClaudePlugin, CloudflareASRPlugin, FireworksPlugin, GeminiPlugin, GladiaPlugin, GoogleCloudSTTPlugin, GranitePlugin, GroqPlugin, LinearPlugin, ObsidianPlugin, OpenAICompatiblePlugin, OpenAIPlugin, ParakeetPlugin, SpeechAnalyzerPlugin, VoxtralPlugin, FileMemoryPlugin, OpenAIVectorMemoryPlugin, ScriptPlugin。

---

## 4. 本地化方案

### 4.1 替换德语 → 简体中文

**改动范围**：
- `DavyWhisper/Resources/Localizable.xcstrings`：删除所有 `de` 条目，添加 `zh-Hans` 简体中文翻译
- `GeneralSettingsView`：语言选择器改为「简体中文 / English」，移除Deutsch选项
- 所有 Plugin 的 `Localizable.xcstrings`：同步执行

**默认语言**：简体中文（`zh-Hans`）

**语言切换机制**：使用 `UserDefaults.standard.set([appLanguage], forKey: "AppleLanguages")`，需要重启 App 生效。

### 4.3 本地化质量保障

6000+ 条目的翻译采用 AI 批量翻译 + 人工分级校对：

| 优先级 | 内容 | 校对要求 |
|--------|------|---------|
| P0（必须人工） | 菜单项、按钮、设置项标签、错误提示 | 人工逐条核对 |
| P1（重点检查） | 提示文案、警告信息、默认值 | AI 翻译 + 人工抽检 |
| P2（次要） | Tooltip、次级说明文字 | AI 翻译 + 抽检 |

翻译流程：AI 批量处理 → P0 逐条人工 → P1 抽检 20% → 验收

### 4.2 双语支持

| 语言 | code | 说明 |
|------|------|------|
| 简体中文 | zh-Hans | 默认语言 |
| English | en | 可切换 |

---

## 5. 品牌重塑

### 5.1 重命名清单

| 项目 | 原值 | 新值 |
|------|------|------|
| App Display Name | DavyWhisper | DavyWhisper |
| Bundle Identifier | com.davywhisper.mac | com.davywhisper.mac |
| Settings Bundle ID | com.davywhisper.mac.Settings | com.davywhisper.mac.Settings |
| App Group ID | 2D8ALY3LCL.com.davywhisper.mac | 需重新注册为 `group.com.davywhisper`（必须在 Apple Developer Portal 注册新 App Group，否则 Keychain Sharing 和 App Group Container 功能失效） |
| HTTP API base path | /v1/ | /v1/（不变） |

### 5.2 涉及文件

- `DavyWhisper/Resources/Info.plist`
- `DavyWhisper/Resources/DavyWhisper.entitlements`
- `DavyWhisper/App/AppConstants.swift`
- `DavyWhisper.xcodeproj`（所有 target 的 Bundle ID）
- `scripts/build-release-local.sh`（`APP_NAME`）
- Homebrew Cask（重命名为 `davywhisper`）

### 5.3 App Icon

替换 `Assets.xcassets/AppIcon.appiconset/` 中的所有尺寸 PNG 文件。

---

## 6. 国内镜像方案

### 6.1 HuggingFace 模型下载镜像

**问题**：WhisperKit 和 Qwen3 的模型从 HuggingFace Hub 下载，国内访问慢或不稳定。

**解决方案**：在 `main.swift` 启动时设置环境变量：

```swift
let useChineseMirror = UserDefaults.standard.bool(forKey: "useChineseMirror")
if useChineseMirror {
    setenv("HF_ENDPOINT", "https://hf-mirror.com", 1)
}
```

`setenv` 必须在任何 HuggingFace SDK 调用之前执行，`main.swift` 是唯一正确位置。

**Settings UI**：在 AdvancedSettings 中增加镜像开关（默认开启）。

### 6.2 国内不可用的服务（已砍掉）

| 服务 | 原因 |
|------|------|
| OpenAI API | GFW 封禁 |
| Gemini API | Google 服务封禁 |
| Google Cloud STT | Google 服务封禁 |
| Mistral API | 大概率封禁 |
| Fireworks AI | 大概率封禁 |

---

## 7. 实施顺序

### Phase 1 — 品牌骨架（最小改动，快速验证）
1. Fork 代码，复制到新目录
2. 全局替换：`DavyWhisper` → `DavyWhisper`，`davywhisper` → `davywhisper`，`com.davywhisper` → `com.davywhisper`
3. 替换 App Icon
4. 验证 build 通过

### Phase 2 — 功能裁剪
1. 移除 Widget Extension target（`DavyWhisperWidgetExtension`、`DavyWhisperWidgetShared`），并从 `DavyWhisper.xcodeproj` 中删除对应 target 引用
2. 删除 `DavyWhisperWidgetShared/WidgetData.swift`（Widget 功能移除后无保留价值）
3. 删除 20 个废弃插件 bundle 目录（见 3.3 节）
4. 删除 Sparkle 相关代码和依赖：
   - 删除 `DavyWhisper/Services/UpdateChecker.swift`
   - 在 `DavyWhisper.xcodeproj` 中移除 Sparkle SPM 依赖（`project.pbxproj` 中的 `Sparkle` package reference）
   - 移除 Settings UI 中"检查更新"入口（`GeneralSettingsView` 或 `AdvancedSettingsView`）
   - 移除 `Info.plist` 中 Sparkle 配置
5. 验证 build 通过

### Phase 3 — 新增 LLM Provider
1. 创建 GLMPlugin（OpenAI-compatible，简单）
2. 创建 KimiPlugin（OpenAI-compatible，简单）
3. 创建 MiniMaxPlugin（非标准协议，需自定义 adapter）
4. 验证三个插件能注册、配置、保存 API Key

### Phase 4 — 本地化
1. 修改 `Localizable.xcstrings`：删 de，加 zh-Hans
2. 修改 `GeneralSettingsView`：语言选择器
3. 所有保留 Plugin 的 `Localizable.xcstrings` 同步处理
4. 逐语言验证 UI 文本正确显示

### Phase 5 — 国内镜像
1. 在 `main.swift` 添加 `HF_ENDPOINT` 环境变量
2. 在 `AdvancedSettingsView` 增加镜像开关
3. 验证 Qwen3 和 WhisperKit 模型下载走镜像

### Phase 6 — 收尾与交付
1. HTTP API 路径验证
2. CLI 工具路径验证
3. Homebrew Cask 重命名
4. 最终 build + DMG 输出

---

## 8. 风险点

| 风险 | 概率 | 影响 | 缓解 |
|------|:---:|:---:|------|
| Sparkle 移除不干净导致编译失败 | 中 | 高 | Phase 1 后先验证 build 再进 Phase 2 |
| Bundle ID 全局替换影响 Plugin SDK | 低 | 中 | 替换时排除 `DavyWhisperPluginSDK` 目录 |
| MiniMax API 格式变更 | 低 | 低 | MiniMaxPlugin 独立实现，不影响其他 Provider |
| 本地化 6000 条目翻译质量 | 高 | 中 | AI 批量翻译 + 人工重点校对 |
| hf-mirror.com 不可用 | 低 | 中 | Settings UI 可切换备用镜像（hf-mirror.com / vipps） |

---

## 9. 技术栈

| 维度 | 规格 |
|------|------|
| 平台 | macOS 14.0+ |
| 语言 | Swift 6 |
| IDE | Xcode 16+ |
| 架构 | MVVM + ServiceContainer（不变） |
| 数据持久化 | SwiftData（History、Profile、PromptAction） |
| Plugin SDK | DavyWhisperPluginSDK（不变） |
| 本地模型 | WhisperKit（Tiny/Base）+ Qwen3 ASR |
| LLM | GLM / Kimi / MiniMax（新增国内 Provider） |
| 云端 ASR | DeepgramPlugin（保留，云端备选） |
| TTS | ElevenLabsPlugin（保留） |
| 自动化 | Webhook HTTP 推送 |
| 国际化 | String(localized:) + Localizable.xcstrings |
| 自动升级 | ❌ 移除 |
| Widget | ❌ 移除 |
