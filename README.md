# DavyWhisper for Mac

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
[![macOS](https://img.shields.io/badge/macOS-14.0%2B-black.svg)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-6-orange.svg)](https://swift.org)

语音转文字与 AI 文本处理工具 for macOS。使用本地 AI 模型或云端 API（Groq、OpenAI）进行音频转写，然后使用自定义 LLM Prompt 处理结果。你的语音数据全程保留在 Mac 本地（使用本地模型）或通过云端 API 处理以获得更快速度。

DavyWhisper `1.0` 定位于可靠的直接下载版本。核心功能包括：系统级语音输入、文件转写、Prompt 处理、配置文件、历史记录、词典、代码片段，以及内置集成。HTTP API、CLI、Widget 和插件 SDK 作为高级功能开放。

相关文档：[docs/1.0-readiness.md](docs/1.0-readiness.md)、[docs/support-matrix.md](docs/support-matrix.md)、[docs/release-checklist.md](docs/release-checklist.md)。

<p align="center">
  <video src="https://github.com/user-attachments/assets/22fe922d-4a4c-47d1-805e-684a148ebd03" autoplay loop muted playsinline width="270"></video>
</p>

## 截图

<p align="center">
  <a href=".github/screenshots/home.png"><img src=".github/screenshots/home.png" width="270" alt="首页仪表盘"></a>
  <a href=".github/screenshots/recording.png"><img src=".github/screenshots/recording.png" width="270" alt="录音与热键"></a>
  <a href=".github/screenshots/prompts.png"><img src=".github/screenshots/prompts.png" width="270" alt="自定义 Prompt"></a>
</p>

<p align="center">
  <a href=".github/screenshots/history.png"><img src=".github/screenshots/history.png" width="270" alt="转写历史"></a>
  <a href=".github/screenshots/dictionary.png"><img src=".github/screenshots/dictionary.png" width="270" alt="词典"></a>
  <a href=".github/screenshots/profiles.png"><img src=".github/screenshots/profiles.png" width="270" alt="配置文件"></a>
</p>

<p align="center">
  <a href=".github/screenshots/general.png"><img src=".github/screenshots/general.png" width="270" alt="通用设置"></a>
  <a href=".github/screenshots/plugins.png"><img src=".github/screenshots/plugins.png" width="270" alt="集成"></a>
  <a href=".github/screenshots/file-transcription.png"><img src=".github/screenshots/file-transcription.png" width="270" alt="文件转写"></a>
</p>

<p align="center">
  <a href=".github/screenshots/snippets.png"><img src=".github/screenshots/snippets.png" width="270" alt="代码片段"></a>
  <a href=".github/screenshots/advanced.png"><img src=".github/screenshots/advanced.png" width="270" alt="高级设置"></a>
</p>

## 功能

### 转写

- **8 种引擎** — WhisperKit（99+ 语言，流式，翻译）、Parakeet TDT v3（25 种欧洲语言，极速）、Apple SpeechAnalyzer（macOS 26+，无需下载模型）、Qwen3 ASR（MLX 本地）、Voxtral（本地 Voxtral Mini 4B，MLX）、Groq Whisper、OpenAI Whisper、OpenAI 兼容（任意 OpenAI 兼容 API）
- **本地或云端** — 所有处理在 Mac 本地完成，或使用 Groq/OpenAI Whisper API 获得更快速度
- **流式预览** — 说话时实时显示部分转写结果（WhisperKit）
- **文件转写** — 支持拖放批量处理多个音视频文件
- **字幕导出** — 导出带时间戳的 SRT 或 WebVTT 字幕文件

### 语音输入

- **系统级** — 通过全局热键实现按键说话、切换模式或混合模式，自动粘贴到任意应用
- **修饰键热键** — 支持将单个修饰键（Command、Shift、Option、Control）设为热键
- **声音反馈** — 录音开始、转写成功、错误的音频提示
- **麦克风选择** — 选择特定输入设备并实时预览

### AI 处理

- **自定义 Prompt** — 使用 LLM Prompt 处理转写结果（或任意文本）。内置 8 个预设（翻译、正式、摘要、语法修复、邮件、列表、精简、解释）。通过全局热键调出独立的 Prompt 调色板 — 一个浮动面板，用于独立于语音输入的 AI 文本处理
- **LLM 提供商** — Apple Intelligence（macOS 26+）、Groq、OpenAI、GLM、Kimi、MiniMax，以及 OpenAI 兼容服务，支持按 Prompt 选择提供商和模型覆盖
- **翻译** — 使用 Apple Translate 在设备端翻译转写结果

### 个性化

- **配置文件** — 按应用和网站覆盖语言、任务、引擎、Prompt、热键和自动提交设置。按应用包名和/或域名匹配，支持子域名
- **词典** — 术语提升云端识别准确率，纠错自动修复常见转写错误，自动学习手动纠正。包含可导入的术语包
- **代码片段** — 带触发词和替换内容的文本快捷方式。支持 `{{DATE}}`、`{{TIME}}`、`{{CLIPBOARD}}` 等占位符
- **历史记录** — 可搜索的转写历史，支持内联编辑、纠正检测、应用上下文跟踪、时间线分组、筛选、批量删除、多选导出、自动保留策略，以及独立窗口（从托盘菜单访问）

### 集成与扩展

- **插件系统** — 通过自定义 LLM 提供商、转写引擎、后处理器和 Action 插件扩展 DavyWhisper。内置 GLM、Kimi、MiniMax、Deepgram、ElevenLabs、Webhook 等插件。参见 [Plugins/README.md](Plugins/README.md)
- **HTTP API** — 本地 REST API，用于与外部工具和脚本集成
- **CLI 工具** — 命令行友好的转写工具

### 通用

- **首页仪表盘** — 使用统计、活动图表和入门教程
- **通用二进制** — 在 Apple Silicon 和 Intel Mac 上原生运行
- **多语言 UI** — 中文、英文
- **启动时运行** — 随 macOS 启动自动运行

## 安装

### Homebrew

```bash
brew install --cask davywhisper/tap/davywhisper
```

### 直接下载

从 [GitHub Releases](https://github.com/DavyWhisper/davywhisper-mac/releases/latest) 下载最新 DMG。

## 快速上手

1. 从 Homebrew 或 DMG 安装 DavyWhisper。
2. 打开设置，授予麦克风和辅助功能权限。
3. 选择一个引擎，必要时下载本地模型。
4. 按下全局热键开始第一次语音输入。

## 系统要求

- macOS 14.0（Sonoma）或更高版本
- 推荐 Apple Silicon（M1 或更高）
- 最少 8GB RAM，16GB+ 推荐（大模型需要更多内存）
- 部分功能（Apple Translate、改进的设置 UI）需要 macOS 15+。Apple Intelligence 和 SpeechAnalyzer 需要 macOS 26+。

## 模型推荐

| 内存 | 推荐模型 |
|------|---------|
| < 8 GB | Whisper Tiny、Whisper Base |
| 8-16 GB | Whisper Small、Whisper Large v3 Turbo、Parakeet TDT v3、Voxtral Mini 4B |
| > 16 GB | Whisper Large v3 |

## 构建

1. 克隆仓库：
   ```bash
   git clone https://github.com/DavyWhisper/davywhisper-mac.git
   cd davywhisper-mac
   ```

2. 用 Xcode 16+ 打开：
   ```bash
   open DavyWhisper.xcodeproj
   ```

3. 选择 DavyWhisper scheme 并构建（Cmd+B）。Swift Package 依赖（WhisperKit、MLXAudio、Sparkle、DavyWhisperPluginSDK）会自动解析。

4. 运行应用。它会显示在菜单栏图标中 — 打开设置下载模型。

5. 提交更改前运行自动化检查：
   ```bash
   xcodebuild test -project DavyWhisper.xcodeproj -scheme DavyWhisper -destination 'platform=macOS,arch=arm64' -parallel-testing-enabled NO CODE_SIGN_IDENTITY='-' CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO
   swift test --package-path DavyWhisperPluginSDK
   ```

## HTTP API

HTTP API 是一个本地自动化接口。它仅绑定到 `127.0.0.1`，默认禁用，仅供本地工具和脚本使用。

在「设置」→「高级」中启用 API 服务器（默认端口：`8978`）。

### 检查状态

```bash
curl http://localhost:8978/v1/status
```

```json
{
  "status": "ready",
  "engine": "whisper",
  "model": "openai_whisper-large-v3_turbo",
  "supports_streaming": true,
  "supports_translation": true
}
```

### 转写音频

```bash
curl -X POST http://localhost:8978/v1/transcribe \
  -F "file=@recording.wav" \
  -F "language=en"
```

```json
{
  "text": "Hello, world!",
  "language": "en",
  "duration": 2.5,
  "processing_time": 0.8,
  "engine": "whisper",
  "model": "openai_whisper-large-v3_turbo"
}
```

可选参数：
- `language` — ISO 639-1 代码（如 `en`、`zh`）。省略则自动检测。
- `task` — `transcribe`（默认）或 `translate`（翻译为英语，仅 WhisperKit）。
- `target_language` — 翻译目标语言 ISO 代码（如 `es`、`fr`）。使用 Apple Translate。

### 模型列表

```bash
curl http://localhost:8978/v1/models
```

```json
{
  "models": [
    {
      "id": "openai_whisper-large-v3_turbo",
      "engine": "whisper",
      "ready": true
    }
  ]
}
```

### 历史记录

```bash
# 搜索历史
curl "http://localhost:8978/v1/history?q=meeting&limit=10&offset=0"

# 删除记录
curl -X DELETE "http://localhost:8978/v1/history?id=<uuid>"
```

### 配置文件

```bash
# 列出所有配置文件
curl http://localhost:8978/v1/profiles

# 切换配置文件开关
curl -X PUT "http://localhost:8978/v1/profiles/toggle?id=<uuid>"
```

### 语音输入控制

```bash
# 开始语音输入
curl -X POST http://localhost:8978/v1/dictation/start

# 停止语音输入
curl -X POST http://localhost:8978/v1/dictation/stop

# 查看语音输入状态
curl http://localhost:8978/v1/dictation/status
```

## CLI 工具

DavyWhisper 包含一个命令行工具，用于 shell 友好的转写。它连接运行中的本地 API 服务器。

### 安装

通过「设置」→「高级」→「CLI 工具」→「安装」安装。这会将 `davywhisper` 二进制文件放入 `/usr/local/bin`。

### 命令

```bash
davywhisper status              # 显示服务器状态
davywhisper models              # 列出可用模型
davywhisper transcribe file.wav # 转写音频文件
```

### 选项

| 选项 | 描述 |
|------|------|
| `--port <N>` | 服务器端口（默认：自动检测）|
| `--json` | JSON 输出 |
| `--language <code>` | 源语言（如 en、zh）|
| `--task <task>` | `transcribe`（默认）或 `translate` |
| `--translate-to <code>` | 翻译目标语言 |

### 示例

```bash
# 带语言和 JSON 输出转写
davywhisper transcribe recording.wav --language zh --json

# 从 stdin 管道输入音频
cat audio.wav | davywhisper transcribe -

# 在脚本中使用
davywhisper transcribe meeting.m4a --json | jq -r '.text'
```

CLI 需要 API 服务器运行中（「设置」→「高级」）。

## 配置文件

配置文件让你可以为不同应用配置转写设置。例如：

- **邮件** — 中文语言，Whisper Large v3
- **Slack** — 英文语言，Parakeet TDT v3
- **终端** — 英文语言，启用自动提交
- **github.com** — 英文语言（匹配任意浏览器）
- **docs.google.com** — 中文语言，翻译为英文

在「设置」→「配置文件」中创建配置文件。分配应用和/或 URL 模式，设置语言/任务/引擎覆盖，分配自定义 Prompt 以自动后处理，配置按配置文件的热键，启用自动提交（自动发送聊天应用中的文本），调整优先级。URL 模式支持子域名匹配——例如 `google.com` 也匹配 `docs.google.com`。

开始语音输入时，DavyWhisper 按以下优先级匹配活动应用和浏览器 URL 与配置文件：
1. **应用 + URL 匹配** — 最高优先级（如 Chrome + github.com）
2. **仅 URL 匹配** — 跨浏览器配置文件（如任意浏览器中的 github.com）
3. **仅应用匹配** — 通用应用配置文件（如整个 Chrome）

活动配置文件名称显示在凹口指示器的徽章中。

多个引擎可以同时加载，以便在配置文件间即时切换。请注意，加载多个本地模型会增加内存使用。云端引擎（Deepgram、ElevenLabs）内存占用可忽略不计。

## 插件

DavyWhisper 支持插件，用于添加自定义 LLM 提供商、转写引擎、后处理器和 Action 插件。插件是 macOS `.bundle` 文件，放置在 `~/Library/Application Support/DavyWhisper/Plugins/`。

内置的插件包括：WhisperKit、Qwen3、Voxtral、Deepgram、ElevenLabs、GLM、Kimi、MiniMax、Webhook 等。

参见 [Plugins/README.md](Plugins/README.md) 获取完整的插件开发指南，包括事件总线、主机服务 API 和清单格式。

## 架构

```
DavyWhisper/
├── davywhisper-cli/           # 命令行工具（status、models、transcribe）
├── Plugins/                   # 内置插件（WhisperKit、Qwen3、Deepgram、ElevenLabs、GLM、Kimi、MiniMax、Webhook）
├── DavyWhisperPluginSDK/      # 插件 SDK（Swift Package）
├── App/                       # 应用入口、依赖注入
├── Models/                    # 数据模型（TranscriptionResult、Profile、PromptAction 等）
├── Services/
│   ├── Cloud/                 # KeychainService、WavEncoder（云端工具）
│   ├── LLM/                   # Apple Intelligence 提供商
│   ├── HTTPServer/            # 本地 REST API（HTTPServer、APIRouter、APIHandlers）
│   ├── ModelManagerService    # 转写调度（委托给插件）
│   ├── AudioRecordingService
│   ├── AudioFileService       # 音视频 → 16kHz PCM 转换
│   ├── HotkeyService
│   ├── TextInsertionService
│   ├── ProfileService         # 按应用配置文件匹配和持久化
│   ├── HistoryService          # 转写历史持久化（SwiftData）
│   ├── DictionaryService       # 自定义术语纠正
│   ├── SnippetService          # 带占位符的文本片段
│   ├── PromptActionService     # 自定义 Prompt 管理（SwiftData）
│   ├── PromptProcessingService # Prompt 执行的 LLM 编排
│   ├── PluginManager           # 插件发现、加载和生命周期
│   ├── PluginRegistryService   # 插件市场（下载、安装、更新）
│   ├── PostProcessingPipeline  # 基于优先级的文本处理链
│   ├── EventBus               # 类型化发布/订阅事件系统
│   ├── TranslationService     # 通过 Apple Translate 实现设备端翻译
│   ├── SubtitleExporter       # SRT/VTT 导出
│   └── SoundService           # 录音事件音频反馈
├── ViewModels/                # MVVM ViewModel（Combine）
├── Views/                     # SwiftUI 视图
└── Resources/                # Info.plist、entitlements、本地化、声音文件
```

**模式：** MVVM 配合 `ServiceContainer` 单例进行依赖注入。ViewModel 使用静态 `_shared` 模式。本地化通过 `String(localized:)` 和 `Localizable.xcstrings` 实现。

## 许可证

GPLv3 — 详见 [LICENSE](LICENSE)。商业许可可用 — 参见 [LICENSE-COMMERCIAL.md](LICENSE-COMMERCIAL.md)。
