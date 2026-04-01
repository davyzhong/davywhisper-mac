# DavyWhisper 项目 Fork 完整工作文档

> 本文档详细记录了从 TypeWhisper fork 到 DavyWhisper 的所有技术工作，供后续开发者参考或继续改进。

---

## 一、项目概述

### 1.1 原始项目
- **TypeWhisper** — macOS 菜单栏语音输入应用，支持 8 种语音识别引擎、HTTP API、CLI，覆盖全球市场
- 技术栈：macOS 14+, Swift 6, Xcode 16+, SwiftData, MVVM
- 原项目包含：主应用、Widget Extension（小组件）、CLI工具、20个插件、DavyWhisperPluginSDK（Swift Package）、完整测试套件

### 1.2 Fork 目标（DavyWhisper）
基于 TypeWhisper fork，专注中国市场：
- Bundle ID: `com.davywhisper.mac`（原为 `com.typewhisper.mac`）
- 添加简体中文本地化（zh-Hans）
- 保留 6 个核心插件（本地优先，适合国内网络）
- 新增 3 个国产 LLM 插件（GLM、Kimi、智谱）
- 添加 HuggingFace 镜像支持（`hf-mirror.com`）
- 移除 Widget Extension、Sparkle自动更新、20个不可用插件
- 插件从源码构建并嵌入 app，避免 GitHub 下载失败

---

## 二、目录结构

```
davywhisper-mac/
├── DavyWhisper/                     # 主应用源码（从 TypeWhisper/ 重命名并修改）
│   ├── App/                         # 入口、ServiceContainer、AppDelegate
│   ├── Models/                      # SwiftData 模型
│   ├── Services/                    # 核心服务层
│   │   └── HTTPServer/              # REST API 服务
│   ├── ViewModels/                  # MVVM ViewModels
│   ├── Views/                       # SwiftUI 视图（含 SetupWizardView）
│   └── Resources/                   # Info.plist、entitlements、Localizable.xcstrings、plugins.json
├── DavyWhisperPluginSDK/            # 插件 SDK（从 TypeWhisperPluginSDK/ 重命名）
├── DavyWhisperTests/                # 测试套件（从 TypeWhisperTests/ 重命名）
├── davywhisper-cli/                 # CLI 工具（从 typewhisper-cli/ 重命名）
├── Plugins/                         # 插件目录
│   ├── WebhookPlugin/               # ✅ 保留
│   ├── Qwen3Plugin/                 # ✅ 保留
│   ├── WhisperKitPlugin/            # ✅ 保留
│   ├── DeepgramPlugin/              # ✅ 保留
│   ├── LiveTranscriptPlugin/        # ✅ 保留
│   ├── ElevenLabsPlugin/            # ✅ 保留
│   ├── GLMPlugin/                   # 🆕 新增（智谱 GLM）
│   ├── KimiPlugin/                  # 🆕 新增（月之暗面 Kimi）
│   ├── MiniMaxPlugin/               # 🆕 新增（MiniMax）
│   ├── QwenLLMPlugin/               # 🆕 新增（通义千问 LLM）
│   ├── translate_localizable.py     # 翻译脚本
│   └── README.md
├── DavyWhisper.xcodeproj/           # 主项目（XcodeGen 生成）
│   └── project.pbxproj              # 自动生成，不入 git
├── project.yml                      # ⭐ XcodeGen 项目定义（344行）
├── scripts/                         # 构建脚本
│   ├── build-release-local.sh      # Release 构建 + DMG 生成
│   ├── check_first_party_warnings.sh
│   ├── update_appcast.py
│   └── take-screenshots.sh
├── .github/
│   ├── dmgbuild-settings.py         # DMG 生成配置
│   ├── dmg-background.png
│   └── workflows/
├── CLAUDE.md                       # Claude Code 项目说明
└── docs/superpowers/               # AI 辅助开发文档
```

**已删除的目录（原 TypeWhisper 源码）：**
- `TypeWhisper/` — 全部删除
- `TypeWhisperPluginSDK/` — 删除
- `TypeWhisperTests/` — 删除
- `typewhisper-cli/` — 删除
- `TypeWhisperWidgetExtension/` — 删除
- `TypeWhisperWidgetShared/` — 删除
- `Plugins/` 下的 20 个已删除插件目录

---

## 三、核心文件变更记录

### 3.1 新建文件

| 文件 | 说明 |
|------|------|
| `DavyWhisper.xcodeproj/project.pbxproj` | 新建 Xcode 项目文件，包含主 app、测试、CLI 三个 target 及 6 个插件依赖 |
| `DavyWhisper/` 目录 | 从 `TypeWhisper/` 复制并全局替换 `TypeWhisper` → `DavyWhisper` |
| `DavyWhisperPluginSDK/` | 从 `TypeWhisperPluginSDK/` 复制并重命名 |
| `DavyWhisperTests/` | 从 `TypeWhisperTests/` 复制并重命名 |
| `davywhisper-cli/` | 从 `typewhisper-cli/` 复制并重命名 |
| `CLAUDE.md` | Claude Code 项目配置文件 |
| `Plugins/GLMPlugin/` | 新增智谱 AI LLM 插件（327 行） |
| `Plugins/KimiPlugin/` | 新增月之暗面 Kimi LLM 插件（303 行） |
| `Plugins/MiniMaxPlugin/` | 新增 MiniMax LLM 插件（299 行） |
| `Plugins/translate_localizable.py` | 批量翻译 Localizable.xcstrings 到简体中文的脚本 |

### 3.2 修改文件

#### 3.2.1 `DavyWhisper.xcodeproj/project.pbxproj`

这是**最核心、最复杂的文件**，经历了多轮修改。主要变更：

**目标重命名（TypeWhisper → DavyWhisper）：**
- `DD00000000000000000001 /* DavyWhisper */` — 主应用 target
- `PRODUCT_NAME = DavyWhisper`
- `path = DavyWhisper;` — PBXGroup 中的路径
- `Contents/MacOS/DavyWhisper` — 可执行文件路径
- `"DavyWhisper Dev"` / `"DavyWhisper"` — scheme 名称
- `remoteInfo = DavyWhisper;` — PBXContainerItemProxy

**Widget Extension target（`DD00000000000000000002`）完整删除：**
- PBXNativeTarget 定义
- PBXFileReference 条目
- PBXBuildFile 条目（WidgetDataService.swift 等）
- PBXGroup 中的 children 引用
- PBXBuildPhase 中的引用
- 根组 `BB00000000000000000101 /* TypeWhisperWidgetExtension */`

**TypeWhisperPluginSDK → DavyWhisperPluginSDK：**
- 28 处 `productName = TypeWhisperPluginSDK;` → `productName = DavyWhisperPluginSDK;`
- 27 处 `XCSwiftPackageProductDependency` 条目补全 `package = RR00000000000000000005` 字段

**Plugin Target Dependencies（6 个插件加入构建依赖）：**

| 插件 | Target UUID | Bundle Ref UUID | Bundle 文件名 |
|------|-------------|-----------------|---------------|
| WebhookPlugin | DD00000000000000000003 | BB00000000000000000133 | WebhookPlugin.bundle |
| Qwen3Plugin | DD00000000000000000009 | BB00000000000000000149 | Qwen3Plugin.bundle |
| WhisperKitPlugin | DD00000000000000000010 | BB00000000000000000153 | WhisperKitPlugin.bundle |
| DeepgramPlugin | DD00000000000000000016 | BB00000000000000000199 | DeepgramPlugin.bundle |
| LiveTranscriptPlugin | DD00000000000000000020 | BB00000000000000000219 | LiveTranscriptPlugin.bundle |
| ElevenLabsPlugin | DD00000000000000000028 | BB00000000000000000266 | ElevenLabsPlugin.bundle |

依赖注入方式（三层链路）：
```
DavyWhisper (PBXNativeTarget dependencies)
  → PBXTargetDependency (TTxxxx)
    → PBXContainerItemProxy (PPxxxx)
      → Plugin PBXNativeTarget (DDxxxx)
```

**Embed App Extensions（`FF00000000000000000081`）PBXCopyFilesBuildPhase：**
- `dstSubfolderSpec = 13` → 目标目录 `Contents/PlugIns`
- 每个插件各添加 2 条 PBXBuildFile 引用（共 12 条，部分重复，WARNING: 有重复 entry 待清理）

**PBXBuildFile 部分新增：**
- 6 个插件的 Embed App Extensions 条目（EE 前缀 UUID）
- 6 个插件的 PBXContainerItemProxy 条目（PP 前缀 UUID）
- 6 个插件的 PBXTargetDependency 条目（TT 前缀 UUID）

**UpdateChecker.swift 引用删除：**
- 原 PBXFileReference `BB00000000000000000070`
- 原 PBXBuildFile `AA00000000000000000070`
- 原 children 引用
- 原 Sources buildPhase 引用
- **原因**：文件不存在于磁盘，属于残留引用

**其他残留引用清理：**
- `TypeWhisperWidgetExtension.appex` 引用删除
- `WidgetDataService.swift` PBXBuildFile 删除（修复了双 `};` 问题）
- `Sparkle` 依赖保留（`AA00000000000000000071`），因 `Updater.app` 仍存在

**DavyWhisper CLI target：**
- Product name: `davywhisper-cli`
- 保留在 CopyFiles phase：`AA00000000000000000107 /* davywhisper-cli in CopyFiles */`
- `dstSubfolderSpec = 6` → `Contents/Library/LaunchServices/`

#### 3.2.2 `DavyWhisper/App/main.swift`

```swift
// 新增内容：

// 1. Bundle.main 本地化覆盖（支持应用内语言切换）
private class OverrideBundle: Bundle
// 拦截 localizedString(forKey:) 实现动态语言切换
// 读取 UserDefaultsKeys.preferredAppLanguage

// 2. HF_ENDPOINT 镜像支持
if UserDefaults.standard.bool(forKey: UserDefaultsKeys.useHuggingFaceMirror) {
    setenv("HF_ENDPOINT", "https://hf-mirror.com", 1)
}
// 在任何 HuggingFace SDK 调用之前执行
```

**关键前置条件**：这两个修改必须在 `DavyWhisperApp.main()` 之前执行，因此放在 `main.swift` 顶部。

#### 3.2.3 `DavyWhisper/Views/SetupWizardView.swift`

引导向导默认引擎/LLM 修改：
- **推荐识别引擎**：Parakeet → **WhisperKit**（本地优先，适合国内网络）
- **推荐云端引擎**：Groq → **Deepgram**
- **推荐 LLM**：Groq → **Kimi**

```swift
// 识别引擎选项（第 339 行）
title: "WhisperKit"

// 云端引擎选项（第 347 行）
title: "Deepgram"

// LLM 选项（第 647 行）
title: "Kimi"
```

#### 3.2.4 `DavyWhisper/Resources/plugins.json`

新增 3 个 LLM 插件条目：

```json
// 智谱 AI GLM
{ "id": "com.davywhisper.glm", "name": "GLM", "category": "llm",
  "downloadURL": "https://github.com/DavyWhisper/davywhisper-mac/releases/..." }

// 月之暗面 Kimi
{ "id": "com.davywhisper.kimi", "name": "Kimi", "category": "llm",
  "downloadURL": "https://github.com/DavyWhisper/davywhisper-mac/releases/..." }

// MiniMax
{ "id": "com.davywhisper.minimax", "name": "MiniMax", "category": "llm",
  "downloadURL": "https://github.com/DavyWhisper/davywhisper-mac/releases/..." }
```

**注意**：下载 URL 指向 DavyWhisper 的 GitHub Releases，国内无法访问（与原插件相同问题）。`PluginRegistryService.swift` 有 bundled fallback 机制，加载失败时使用 bundled `plugins.json`。

#### 3.2.5 `DavyWhisper/Services/PluginRegistryService.swift`

- 已有 bundled fallback 机制（当远程 fetch 失败时从 `Bundle.main` 加载 `plugins.json`）
- HF_ENDPOINT 通过 `main.swift` 中的 `setenv()` 在 SDK 调用前设置

#### 3.2.6 项目配置文件

| 文件 | 变更 |
|------|------|
| `README.md` | 重命名提及 TypeWhisper → DavyWhisper |
| `SECURITY.md` | 更新项目名称 |
| `TRADEMARK.md` | 更新项目名称 |
| `CONTRIBUTING.md` | 更新项目名称 |
| `LICENSE-COMMERCIAL.md` | 更新版权年份和项目名称 |
| `ExportOptions.plist` | 更新内容 |
| `docs/1.0-readiness.md` | 更新内容 |
| `docs/release-checklist.md` | 更新内容 |
| `docs/support-matrix.md` | 更新内容 |
| `scripts/build-release-local.sh` | 更新 `APP_NAME=DavyWhisper`、路径适配 |
| `scripts/check_first_party_warnings.sh` | 小幅更新 |
| `scripts/update_appcast.py` | 小幅更新 |
| `scripts/take-screenshots.sh` | 小幅更新 |
| `.github/dmgbuild-settings.py` | 更新 App 名称引用 |

### 3.3 删除的插件（20 个）

```
AssemblyAIPlugin, CerebrasPlugin, ClaudePlugin,
CloudflareASRPlugin, FileMemoryPlugin, FireworksPlugin,
GeminiPlugin, GladiaPlugin, GoogleCloudSTTPlugin,
GranitePlugin, GroqPlugin, LinearPlugin,
ObsidianPlugin, OpenAICompatiblePlugin, OpenAIPlugin,
OpenAIVectorMemoryPlugin, ParakeetPlugin, ScriptPlugin,
SpeechAnalyzerPlugin, VoxtralPlugin
```

**删除原因**：依赖 GitHub Releases 分发下载，国内网络不可达（无法安装）。保留了本地优先或国内可用的插件（WhisperKit、Qwen3、Webhook、LiveTranscript、Deepgram、ElevenLabs）。

---

## 四、XcodeGen 迁移（2026-04-01 完成）

原 pbxproj (5707 行, 28 target, 19 死 target) 已被 `project.yml` (344 行) + XcodeGen 替代。

详见 `xcodegen-migration-plan.md`。

### 4.1 当前 target 清单

| Target | 类型 | 说明 |
|--------|------|------|
| DavyWhisper | application | 主 app |
| davywhisper-cli | tool | CLI 工具 |
| DavyWhisperTests | bundle.unit-test | 单元测试 |
| 10 个 Plugin bundle | bundle | Webhook, Qwen3, WhisperKit, Deepgram, LiveTranscript, ElevenLabs, GLM, Kimi, MiniMax, QwenLLM |

### 4.2 App Bundle 结构

```
DavyWhisper.app/
  Contents/
    MacOS/
      DavyWhisper
    Frameworks/
      DavyWhisperPluginSDK.framework/
    Resources/
      davywhisper-cli
      WebhookPlugin.bundle/
      ... (10 个 plugin bundle)
```

> 插件在 Resources/（XcodeGen embed 默认行为）。PluginManager 已更新为同时扫描 PlugIns/ 和 Resources/。

---

## 五、已知问题与待办

### 5.1 已解决问题

| 问题 | 解决方案 |
|------|----------|
| Embed App Extensions 重复 entry | XcodeGen 重新生成，无重复 |
| GLM/Kimi/MiniMax 未注册到 Xcode | project.yml 中定义，XcodeGen 自动注册 |
| 构建产物中无插件 bundle | 10 个 bundle 嵌入 Resources/，PluginManager 已支持 |
| pbxproj 体积庞大 | 5707→344 行 YAML (生成的 pbxproj 不入 git) |

### 5.2 剩余待办

| 优先级 | 事项 |
|--------|------|
| P0 | Release 构建验证 + DMG 输出 |
| P1 | AppStore 构建配置（如需上架） |
| P2 | 完整本地化审查（zh-Hans 翻译质量） |
| P2 | 国内网络环境测试插件安装流程 |
| P3 | Homebrew Cask 重命名为 davywhisper |

---

## 六、构建方法

### 6.1 项目生成（必须先执行）

```bash
cd /Users/qiming/workspace/typewhisper-zh/davywhisper-mac
xcodegen generate
# 或: ./scripts/generate-projects.sh
```

### 6.2 Debug 构建

```bash
xcodebuild -project DavyWhisper.xcodeproj \
  -scheme DavyWhisper \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  CODE_SIGN_IDENTITY='-' CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO
```

### 6.3 Release 构建 + DMG

```bash
bash scripts/build-release-local.sh
```

### 6.4 Xcode GUI 开发

```bash
xcodegen generate  # 确保项目最新
open DavyWhisper.xcodeproj
# 选中 DavyWhisper scheme，Cmd+B 构建
```

---

## 七、技术债务与架构说明

### 7.1 为什么选择插件源码构建而非下载？

**背景**：TypeWhisper 所有插件通过 `plugins.json` 中的 `downloadURL` 从 GitHub Releases 下载 ZIP。但 GitHub 在中国大陆无法访问，导致 SetupWizard 报 `Failed to extract ZIP` 错误。

**DavyWhisper 的解决思路**：
- 10 个插件的源码保留在 `Plugins/` 目录
- `project.yml` 定义所有插件为 bundle target，XcodeGen 自动注册
- Xcode 编译时自动构建插件 bundle，embed 到 app bundle
- PluginManager 扫描 `Contents/Resources/` 和 `Contents/PlugIns/` 发现 bundle
- 无需网络下载

### 7.2 添加新插件（已简化）

1. 在 `Plugins/YourPlugin/` 创建源码 + `manifest.json`
2. 在 `project.yml` 的 `targets:` 下添加 bundle target（~10 行 YAML）
3. 在 DavyWhisper target 的 dependencies 添加 `- target: YourPlugin` + `embed: true`
4. 运行 `xcodegen generate`

无需手动编辑 pbxproj。

### 7.2 HF_ENDPOINT 为什么在 main.swift 中设置？

`hf_hub` SDK（用于 WhisperKit/Qwen3 下载模型）在**第一次使用**时读取 `HF_ENDPOINT` 环境变量。一旦读取后不再检查。因此必须：
1. 在任何可能触发 hf_hub 初始化的代码之前设置
2. `setenv()` 必须在 Swift 代码执行前调用（因为 Swift 的 `ProcessInfo.processInfo.environment` 在读取后不会动态更新）

### 7.3 语言切换实现原理

macOS 应用的语言由 `Bundle.main` 的 `localizedString(forKey:tableName:)` 决定。TypeWhisper 原版直接使用 `Bundle.main`，无法动态切换。DavyWhisper 通过：
1. 创建 `OverrideBundle: Bundle` 类，重写 `localizedString(forKey:tableName:)`
2. `object_setClass(Bundle.main, OverrideBundle.self)` 替换 `Bundle.main` 的类
3. 读取 `UserDefaults[UserDefaultsKeys.preferredAppLanguage]` 获取用户选择的语言
4. 动态加载对应 `.lproj` 目录实现切换

**注意**：当前语言切换 UI 行为需要测试验证。

---

## 八、工作时间线

| 阶段 | 内容 | 状态 |
|------|------|------|
| Phase 1 | Fork 项目目录结构，重命名 TypeWhisper → DavyWhisper | ✅ |
| Phase 2 | 手动创建 pbxproj，注册主 app、测试、CLI + 6 插件 | ✅ |
| Phase 3 | 删除 Widget Extension、20 死插件目录 | ✅ |
| Phase 4 | 添加 HF_ENDPOINT 镜像、语言切换、SetupWizard 默认引擎 | ✅ |
| Phase 5 | 创建 GLM/Kimi/MiniMax/QwenLLM 插件 | ✅ |
| Phase 6 | **XcodeGen 迁移**：project.yml (344行) 替代 pbxproj (5707行) | ✅ |
| Phase 7 | 本地化 zh-Hans 转换、Sparkle 移除、bundle ID 修正 | ✅ |
| Phase 8 | Phase 3 清理：删除备份/旧项目/添加脚本+gitignore | ✅ |
| 待做 | Release 构建 + DMG 验证 | |
| 待做 | AppStore 构建配置（如需上架） | |

---

*文档生成时间：2026-03-31*
*最后更新：2026-04-01 (XcodeGen 迁移后)*
