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
│   ├── DavyWhisperPlugins.xcodeproj/  # 独立 Xcode 项目
│   ├── WebhookPlugin/               # ✅ 保留
│   ├── Qwen3Plugin/                 # ✅ 保留
│   ├── WhisperKitPlugin/            # ✅ 保留
│   ├── DeepgramPlugin/              # ✅ 保留
│   ├── LiveTranscriptPlugin/        # ✅ 保留
│   ├── ElevenLabsPlugin/            # ✅ 保留
│   ├── GLMPlugin/                   # 🆕 新增（智谱 GLM）
│   ├── KimiPlugin/                  # 🆕 新增（月之暗面 Kimi）
│   ├── MiniMaxPlugin/               # 🆕 新增（MiniMax）
│   ├── project.yml                  # XcodeGen 配置
│   ├── translate_localizable.py     # 翻译脚本
│   └── README.md
├── DavyWhisper.xcodeproj/           # 主项目（新建）
│   └── project.pbxproj              # 核心配置文件
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

## 四、pbxproj 关键结构解析

### 4.1 Target UUID 对照表

| Target | UUID | 类型 |
|--------|------|------|
| DavyWhisper（主应用） | `DD00000000000000000001` | PBXNativeTarget |
| DavyWhisperTests | `40F22D3F350BA09ADEFBD2CB` | PBXNativeTarget |
| WebhookPlugin | `DD00000000000000000003` | PBXNativeTarget |
| Qwen3Plugin | `DD00000000000000000009` | PBXNativeTarget |
| WhisperKitPlugin | `DD00000000000000000010` | PBXNativeTarget |
| DeepgramPlugin | `DD00000000000000000016` | PBXNativeTarget |
| LiveTranscriptPlugin | `DD00000000000000000020` | PBXNativeTarget |
| ElevenLabsPlugin | `DD00000000000000000028` | PBXNativeTarget |

### 4.2 Build Phases 顺序

```
FF00000000000000000002  Sources
FF00000000000000000001  Frameworks
FF00000000000000000003  Resources
FF00000000000000000004  CopyFiles (davywhisper-cli → Contents/Library/LaunchServices)
FF00000000000000000036  Embed Frameworks (DavyWhisperPluginSDK)
FF00000000000000000081  Embed App Extensions (6 plugins → Contents/PlugIns)
FF00000000000000000007  Remove CLI for App Store
```

### 4.3 PBXContainerItemProxy 链路（插件嵌入原理）

```swift
// pbxproj 中每个插件的依赖链路：

// 1. PBXContainerItemProxy（告诉 Xcode 远程 target 存在）
PPxxxx /* PBXContainerItemProxy */ = {
    isa = PBXContainerItemProxy;
    containerPortal = EE00000000000000000001 /* Project object */;
    proxyType = 1;
    remoteGlobalIDString = DD00000000000000000003;  // 插件 target UUID
    remoteInfo = WebhookPlugin;
};

// 2. PBXTargetDependency（声明这是一个 target 依赖）
TTxxxx /* PBXTargetDependency */ = {
    isa = PBXTargetDependency;
    targetProxy = PPxxxx /* PBXContainerItemProxy */;
};

// 3. DavyWhisper dependencies 数组引用
dependencies = (
    TTxxxx /* WebhookPlugin in Dependencies */,  // UUID 引用，非完整对象
);

// 4. PBXCopyFilesBuildPhase（Embed App Extensions）
FF00000000000000000081 /* Embed App Extensions */ = {
    dstSubfolderSpec = 13;  // = PlugIns 目录
    files = (
        EEyyyy /* WebhookPlugin.bundle in Embed App Extensions */,
    );
};

// 5. PBXBuildFile（告诉 Xcode 哪个文件引用了哪个 fileRef）
EEyyyy /* WebhookPlugin.bundle in Embed App Extensions */ = {
    isa = PBXBuildFile;
    fileRef = BB00000000000000000133 /* WebhookPlugin.bundle */;
};
```

---

## 五、已知问题与待办

### 5.1 已知问题（需修复）

#### 问题 1：Embed App Extensions 有重复 entry（WARNING）

**现象**：构建输出显示
```
warning: Skipping duplicate build file in Copy Files build phase: .../WebhookPlugin.bundle
```
每个插件在 `FF00000000000000000081` phase 中出现了 **2 次**。

**原因**：Python 脚本多次运行，每次都追加了新 entry，未做去重。

**修复方案**：清理 pbxproj 中 `FF00000000000000000000081` phase 的 `files` 数组，每个插件只保留 1 条。

#### 问题 2：GLMPlugin / KimiPlugin / MiniMaxPlugin 未注册到 Xcode 项目

**现象**：这 3 个新插件有源代码文件（300-327 行/个），但 `project.pbxproj` 中 **0 次提及**，即 Xcode 不知道要编译它们。

**影响**：这 3 个插件目前无法通过 Xcode 构建。

**修复方案**：
1. 在 `DavyWhisperPlugins.xcodeproj` 中添加这 3 个插件 target（推荐，因为插件有自己的独立 Xcode 项目）
2. 或在 `DavyWhisper.xcodeproj` 中添加这 3 个插件 target
3. 更新 `Plugins/project.yml`（XcodeGen 配置）
4. 为这 3 个插件添加 PBXContainerItemProxy、PBXTargetDependency 和 Embed App Extensions entry

#### 问题 3：构建产物中无插件 bundle（推测）

**现象**：Debug 构建成功，但 Release 构建仍在进行中，未验证 `DavyWhisper.app/Contents/PlugIns/` 下是否有 6 个 `.bundle` 文件。

**验证方法**：
```bash
ls -la ~/Library/Developer/Xcode/DerivedData/DavyWhisper-*/Build/Products/Release/DavyWhisper.app/Contents/PlugIns/
```

### 5.2 待办事项

| 优先级 | 事项 | 预计工作量 |
|--------|------|-----------|
| P0 | 验证 Release 构建成功且 PlugIns 有 6 个 bundle | 10 分钟 |
| P0 | 清理 Embed App Extensions 重复 entry | 5 分钟 |
| P1 | 将 GLM/Kimi/MiniMax 插件注册到 Xcode 项目 | 2 小时 |
| P1 | 重新生成 DMG 安装包到桌面 | 5 分钟 |
| P2 | 完整本地化审查（运行 `translate_localizable.py` 验证中文翻译覆盖度） | 1 小时 |
| P2 | 在国内网络环境测试 SetupWizard 插件安装流程 | 30 分钟 |
| P3 | 添加 SparkleUpdater.target 或完全移除自动更新依赖 | 1 小时 |
| P3 | 测试 HF_ENDPOINT 镜像是否正常工作 | 30 分钟 |

---

## 六、构建方法

### 6.1 Debug 构建（当前可用）

```bash
cd /Users/Davy/workspace-bak/typewhisper-zh/davywhisper-mac

xcodebuild -project DavyWhisper.xcodeproj \
  -scheme DavyWhisper \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  CODE_SIGN_IDENTITY='-' \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO
```

### 6.2 Release 构建 + DMG（当前正在运行）

```bash
cd /Users/Davy/workspace-bak/typewhisper-zh/davywhisper-mac
bash scripts/build-release-local.sh
```

**输出路径**：`build-release/DavyWhisper-v{version}.dmg`

**部署到桌面**（构建完成后）：
```bash
cp build-release/DavyWhisper-v*.dmg ~/Desktop/
```

### 6.3 Xcode GUI 开发

```bash
cd /Users/Davy/workspace-bak/typewhisper-zh/davywhisper-mac
open DavyWhisper.xcodeproj
# 选中 DavyWhisper scheme，Cmd+B 构建
```

### 6.4 插件 Xcode 项目

```bash
cd Plugins
open DavyWhisperPlugins.xcodeproj
```

---

## 七、技术债务与架构说明

### 7.1 为什么选择插件源码构建而非下载？

**背景**：TypeWhisper 所有插件通过 `plugins.json` 中的 `downloadURL` 从 GitHub Releases 下载 ZIP。但 GitHub 在中国大陆无法访问，导致 SetupWizard 报 `Failed to extract ZIP` 错误。

**DavyWhisper 的解决思路**：
- 6 个核心插件的 `.swift` 源码保留在 `Plugins/` 目录
- 在 `DavyWhisper.xcodeproj` 中添加这 6 个插件作为 build dependency
- Xcode 编译时自动构建插件 bundle，CopyFiles phase 将其复制到 `PlugIns/` 目录
- 这样 app 本身包含所有插件，无需网络下载

**架构限制**：
- 插件数量受限于 Xcode 项目中注册的目标数量
- 插件更新需要重新编译 app
- 动态加载插件需要额外的 dlopen 机制（目前未实现，插件是静态链接到构建系统）

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

## 八、pbxproj 编辑规范（经验总结）

1. **UUID 前缀约定**（非强制但推荐）：
   - `AA` — PBXBuildFile（主应用源文件）
   - `BB` — PBXFileReference
   - `CC` — PBXGroup
   - `DD` — PBXNativeTarget
   - `EE` — PBXBuildFile（插件/CopyFiles）、PBXProject
   - `FF` — PBXBuildPhase、XCConfigurationList
   - `GG` — 旧版 PBXTargetDependency（遗留）
   - `TT` — PBXTargetDependency（新）
   - `PP` — PBXContainerItemProxy
   - `RR` — XCRemoteSwiftPackageReference
   - `WW/XX/YY/ZZ` — 脚本生成的临时 UUID

2. **括号必须平衡**：用 Python 验证 `content.count('{') == content.count('}')`

3. **dependencies 数组只存 UUID 引用**：`WWxxx /* Name in Dependencies */` 不是完整 PBXBuildFile 对象

4. **CopyFiles dstSubfolderSpec**：13 = PlugIns，6 = Library/LaunchServices

5. **DavyWhisper 主项目 + 插件独立项目**：插件有自己的 `DavyWhisperPlugins.xcodeproj`，主项目通过 `PBXContainerItemProxy` 引用其中的 target

---

## 九、后续开发者操作指南

### 9.1 添加新插件到构建系统

**步骤 1**：在 `Plugins/YourPlugin/` 创建 bundle 结构：
```
Plugins/YourPlugin/
├── YourPlugin.swift
├── manifest.json
└── Localizable.xcstrings
```

**步骤 2**：在 `DavyWhisperPlugins.xcodeproj`（或主 `DavyWhisper.xcodeproj`）中添加 PBXNativeTarget

**步骤 3**：在 `DavyWhisper.xcodeproj` 中添加三层依赖：
```python
# 1. PBXContainerItemProxy
proxy_uuid = "PP" + uuid22
proxy_entry = f'{proxy_uuid} /* PBXContainerItemProxy */ = {{isa = PBXContainerItemProxy; containerPortal = EE...; proxyType = 1; remoteGlobalIDString = {plugin_target_uuid}; remoteInfo = YourPlugin; }};'

# 2. PBXTargetDependency
td_uuid = "TT" + uuid22
td_entry = f'{td_uuid} /* PBXTargetDependency YourPlugin */ = {{isa = PBXTargetDependency; targetProxy = {proxy_uuid} /* PBXContainerItemProxy */; }};'

# 3. 插入到 dependencies 数组
# 在 DW target 的 dependencies 中添加:
#   {td_uuid} /* YourPlugin in Dependencies */,

# 4. Embed App Extensions PBXBuildFile
bf_uuid = "EE" + uuid22
bf_entry = f'{bf_uuid} /* YourPlugin.bundle in Embed App Extensions */ = {{isa = PBXBuildFile; fileRef = {bundle_file_ref_uuid} /* YourPlugin.bundle */; }};'
# 在 FF00000000000000000081 phase 的 files 数组中添加 bf_uuid 引用
```

**步骤 4**：验证构建：
```bash
xcodebuild -project DavyWhisper.xcodeproj -scheme DavyWhisper -configuration Debug ...
ls -la ~/Library/Developer/Xcode/DerivedData/DavyWhisper-*/Build/Products/Debug/DavyWhisper.app/Contents/PlugIns/
```

### 9.2 完整重写 project.pbxproj 的方法

如果项目损坏严重，最可靠的方法是从头生成：

```bash
# 1. 创建备份
cp project.pbxproj project.pbxproj.bak

# 2. 使用 XcodeGen（需要 project.yml）
# 编辑 project.yml 配置 targets 和依赖
xcodegen generate

# 3. 手动调整 XcodeGen 无法处理的插件依赖链路
```

---

## 十、工作时间线

| 阶段 | 内容 |
|------|------|
| Phase 1 | Fork 项目目录结构，重命名 TypeWhisper → DavyWhisper |
| Phase 2 | 创建 `DavyWhisper.xcodeproj/project.pbxproj`，注册主 app、测试、CLI 三个 target |
| Phase 3 | 删除 Widget Extension target 及所有残留引用 |
| Phase 4 | 添加 6 个核心插件的构建依赖（PBXContainerItemProxy → PBXTargetDependency → Embed App Extensions） |
| Phase 5 | 修复 `TypeWhisperPluginSDK` → `DavyWhisperPluginSDK`（productName + package 字段） |
| Phase 6 | 修改 `SetupWizardView.swift` 默认引擎 |
| Phase 7 | 添加 HF_ENDPOINT 镜像支持到 `main.swift` |
| Phase 8 | 修改 `plugins.json` 添加 3 个新 LLM 插件 |
| Phase 9 | 创建 GLMPlugin、KimiPlugin、MiniMaxPlugin 源码（300+ 行/个） |
| Phase 10 | 创建 `translate_localizable.py` 翻译脚本 |
| Phase 11 | 修复 `UpdateChecker.swift` 缺失文件引用 |
| Phase 12 | Debug 构建成功 ✅ |
| Phase 13 | Release 构建 + DMG 生成（进行中） |
| 待做 | 清理 Embed App Extensions 重复 entry |
| 待做 | 将新 3 个插件注册到 Xcode 项目 |
| 待做 | 完整验证和测试 |

---

*文档生成时间：2026-03-31*
*最后更新人：Claude Code (Sonnet 4.6)*
