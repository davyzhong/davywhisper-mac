# DavyWhisper 插件 SDK

为 [DavyWhisper](https://github.com/DavyWhisper/davywhisper-mac) 构建插件，添加转写引擎、LLM 提供商、后处理器和自定义 Action。

## 快速开始

### 1. 创建 Xcode Bundle Target

在 Xcode 项目中：
1. **File > New > Target > macOS > Bundle**
2. 设置 **Product Name** 为插件名称（如 `MyPlugin`）
3. 添加 `DavyWhisperPluginSDK` 包作为依赖

### 2. 添加清单

在 bundle 的 `Contents/Resources/` 中创建 `manifest.json`：

```json
{
  "id": "com.yourname.myplugin",
  "name": "My Plugin",
  "version": "1.0.0",
  "minHostVersion": "1.0",
  "minOSVersion": "15.0",
  "author": "Your Name",
  "principalClass": "MyPlugin"
}
```

- `id` — 唯一的反向域名标识符
- `principalClass` — 必须与插件类上的 `@objc(ClassName)` 匹配
- `minHostVersion` — 所需最低 DavyWhisper 版本
- `minOSVersion` — 所需最低 macOS 版本（旧系统上插件被跳过）

### 3. 实现插件

```swift
import Foundation
import SwiftUI
import DavyWhisperPluginSDK

@objc(MyPlugin)
final class MyPlugin: NSObject, PostProcessorPlugin, @unchecked Sendable {
    static let pluginId = "com.yourname.myplugin"
    static let pluginName = "My Plugin"

    private var host: HostServices?

    required override init() { super.init() }

    func activate(host: HostServices) {
        self.host = host
    }

    func deactivate() {
        host = nil
    }

    // PostProcessorPlugin
    var processorName: String { "My Processor" }
    var priority: Int { 500 }

    @MainActor
    func process(text: String, context: PostProcessingContext) async throws -> String {
        // 在此处转换文本
        return text.uppercased()
    }
}
```

### 4. 安装和测试

构建插件后，使用以下方式之一安装：

- **从文件安装**：设置 → 集成 → 从文件安装...（选择 `.bundle`）
- **手动**：将 `.bundle` 复制到 `~/Library/Application Support/DavyWhisper/Plugins/`
- **符号链接**（开发用）：`ln -s /path/to/DerivedData/.../MyPlugin.bundle ~/Library/Application\ Support/DavyWhisper/Plugins/`

在设置 → 集成中启用您的插件。

---

## 插件类型

### TranscriptionEnginePlugin

添加语音转文字引擎。接收原始音频，返回文本。

```swift
@objc(MyTranscriptionEngine)
final class MyTranscriptionEngine: NSObject, TranscriptionEnginePlugin, @unchecked Sendable {
    static let pluginId = "com.yourname.mytranscription"
    static let pluginName = "My Transcription"

    private var host: HostServices?

    required override init() { super.init() }
    func activate(host: HostServices) { self.host = host }
    func deactivate() { host = nil }

    var providerId: String { "my-engine" }
    var providerDisplayName: String { "My Engine" }
    var isConfigured: Bool { true }
    var transcriptionModels: [PluginModelInfo] {
        [PluginModelInfo(id: "default", displayName: "Default Model")]
    }
    var selectedModelId: String? { "default" }
    func selectModel(_ modelId: String) {}
    var supportsTranslation: Bool { false }

    func transcribe(
        audio: AudioData,
        language: String?,
        translate: Bool,
        prompt: String?
    ) async throws -> PluginTranscriptionResult {
        // audio.samples  - [Float] 16kHz 单声道 PCM
        // audio.wavData   - 预编码 WAV 数据
        // audio.duration  - TimeInterval
        let text = "transcribed text"
        return PluginTranscriptionResult(text: text)
    }
}
```

### LLMProviderPlugin

添加 LLM 用于 Prompt 处理（文本转换、摘要等）。

```swift
@objc(MyLLMProvider)
final class MyLLMProvider: NSObject, LLMProviderPlugin, @unchecked Sendable {
    static let pluginId = "com.yourname.myllm"
    static let pluginName = "My LLM"

    private var host: HostServices?

    required override init() { super.init() }
    func activate(host: HostServices) { self.host = host }
    func deactivate() { host = nil }

    var providerName: String { "My LLM" }
    var isAvailable: Bool { host?.loadSecret(key: "apiKey") != nil }
    var supportedModels: [PluginModelInfo] {
        [PluginModelInfo(id: "my-model", displayName: "My Model")]
    }

    func process(systemPrompt: String, userText: String, model: String?) async throws -> String {
        let apiKey = host?.loadSecret(key: "apiKey") ?? ""
        // 在此处调用您的 LLM API
        return "processed result"
    }
}
```

对于 OpenAI 兼容 API，使用内置辅助工具：

```swift
let helper = PluginOpenAIChatHelper(baseURL: "https://api.example.com")
let result = try await helper.process(
    apiKey: apiKey, model: "my-model",
    systemPrompt: systemPrompt, userText: userText
)
```

### PostProcessorPlugin

在转写后转换文本。按优先级顺序运行（数字越小越靠前）。

```swift
var processorName: String { "My Processor" }
var priority: Int { 500 }  // 内置：LLM=300，Snippets=500，Dictionary=600

@MainActor
func process(text: String, context: PostProcessingContext) async throws -> String {
    // context.appName           - 活动应用名称
    // context.bundleIdentifier  - 活动应用包 ID
    // context.url               - 浏览器 URL（如可用）
    // context.language          - 检测到的语言
    return text
}
```

### ActionPlugin

对文本执行自定义操作（如创建 issue、发送到 API）。

```swift
@objc(MyAction)
final class MyAction: NSObject, ActionPlugin, @unchecked Sendable {
    static let pluginId = "com.yourname.myaction"
    static let pluginName = "My Action"

    private var host: HostServices?

    required override init() { super.init() }
    func activate(host: HostServices) { self.host = host }
    func deactivate() { host = nil }

    var actionName: String { "Do Something" }
    var actionId: String { "my-action" }
    var actionIcon: String { "star.fill" }  // SF Symbol 名称

    func execute(input: String, context: ActionContext) async throws -> ActionResult {
        // context.originalText - LLM 处理前的文本
        // input                - LLM 处理后的文本
        return ActionResult(
            success: true,
            message: "Done!",
            url: "https://example.com",       // 可选，使结果可点击
            icon: "checkmark.circle.fill",     // 可选 SF Symbol
            displayDuration: 3.0              // 可选，显示秒数
        )
    }
}
```

### 多用途插件

单个插件类可以实现多个协议：

```swift
@objc(MyCloudPlugin)
final class MyCloudPlugin: NSObject, TranscriptionEnginePlugin, LLMProviderPlugin, @unchecked Sendable {
    // 在一个插件中实现两个协议
}
```

---

## 主机服务

插件在激活时接收 `HostServices` 实例：

```swift
func activate(host: HostServices) {
    self.host = host

    // 安全存储（插件范围的 keychain）
    try host.storeSecret(key: "apiKey", value: "sk-...")
    let key = host.loadSecret(key: "apiKey")

    // 偏好设置（插件范围的 UserDefaults）
    host.setUserDefault("value", forKey: "myPref")
    let pref = host.userDefault(forKey: "myPref")

    // 文件存储（~/Library/Application Support/DavyWhisper/PluginData/<pluginId>/）
    let dataDir = host.pluginDataDirectory

    // 应用上下文
    let appName = host.activeAppName
    let bundleId = host.activeAppBundleId

    // 配置文件名称
    let profiles = host.availableProfileNames
}
```

---

## 事件总线

订阅应用事件：

```swift
func activate(host: HostServices) {
    host.eventBus.subscribe { event in
        switch event {
        case .transcriptionCompleted(let payload):
            print("转写完成：\(payload.finalText)")
            print("引擎：\(payload.engineUsed)")
            print("应用：\(payload.appName ?? "未知")")
        case .recordingStarted(let payload):
            print("录音开始于 \(payload.timestamp)")
        case .recordingStopped(let payload):
            print("时长：\(payload.durationSeconds)秒")
        case .textInserted(let payload):
            print("已插入：\(payload.text)")
        case .actionCompleted(let payload):
            print("Action \(payload.actionId)：\(payload.message)")
        case .transcriptionFailed(let payload):
            print("错误：\(payload.error)")
        }
    }
}
```

---

## 设置 UI

提供 SwiftUI 视图用于插件配置：

```swift
var settingsView: AnyView? {
    AnyView(MySettingsView(plugin: self))
}
```

当用户点击设置 → 集成中的齿轮图标时，视图以 sheet 形式显示。

---

## 内置辅助工具

### PluginOpenAITranscriptionHelper

用于 OpenAI 兼容 Whisper API：

```swift
let helper = PluginOpenAITranscriptionHelper(baseURL: "https://api.groq.com/openai")
let result = try await helper.transcribe(
    audio: audio, apiKey: apiKey, modelName: "whisper-large-v3",
    language: "en", translate: false, prompt: nil
)
```

### PluginOpenAIChatHelper

用于 OpenAI 兼容聊天 API：

```swift
let helper = PluginOpenAIChatHelper(baseURL: "https://api.openai.com")
let result = try await helper.process(
    apiKey: apiKey, model: "gpt-4o",
    systemPrompt: "Fix grammar", userText: inputText
)
```

### PluginWavEncoder

将音频样本编码为 WAV：

```swift
let wavData = PluginWavEncoder.encode(samples, sampleRate: 16000)
```

---

## 清单参考

| 字段 | 必需 | 描述 |
|------|:----:|------|
| `id` | 是 | 唯一反向域名 ID（如 `com.yourname.myplugin`）|
| `name` | 是 | 显示名称 |
| `version` | 是 | 语义化版本字符串（如 `1.0.0`）|
| `minHostVersion` | 否 | 最低 DavyWhisper 版本 |
| `minOSVersion` | 否 | 最低 macOS 版本（如 `15.0`、`26.0`）。旧系统上插件被跳过。|
| `author` | 否 | 作者名称 |
| `principalClass` | 是 | Objective-C 类名，必须与 `@objc(Name)` 匹配 |

---

## 发布

通过 DavyWhisper 插件市场分发：

1. 以 Release 配置构建插件
2. 压缩 `.bundle`：`ditto -ck --sequesterRsrc MyPlugin.bundle MyPlugin.zip`
3. 托管 ZIP（GitHub Releases、您自己的服务器等）
4. 提交 PR 将您的插件添加到[插件注册表](https://github.com/DavyWhisper/davywhisper-mac/blob/gh-pages/plugins.json)

注册表条目格式：

```json
{
  "id": "com.yourname.myplugin",
  "name": "My Plugin",
  "version": "1.0.0",
  "minHostVersion": "1.0",
  "minOSVersion": "15.0",
  "author": "Your Name",
  "description": "插件功能描述。",
  "category": "transcription|llm|postprocessor|action",
  "size": 12345678,
  "downloadURL": "https://example.com/MyPlugin.zip",
  "iconSystemName": "star.fill"
}
```

---

## 要求

- macOS 15.0+
- Swift 6.0
- DavyWhisper 1.0+
