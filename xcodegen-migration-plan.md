# DavyWhisper.xcodeproj XcodeGen 迁移方案

> 日期: 2026-04-01
> 状态: ✅ 已完成

---

## 1. 现状分析

### 1.1 原问题（已解决）

| 问题 | 解决方式 |
|------|----------|
| **体积庞大** 5707 行，28 个 native target | → XcodeGen 从 project.yml (344行) 生成 ~2341 行 pbxproj |
| **死 target** 19 个已删除的 plugin target | → project.yml 只定义 13 个活跃 target |
| **手动编辑困难** .bak/.pre_plugin_add 备份文件 | → 全部删除，不再需要手动编辑 pbxproj |
| **重复条目** Embed App Extensions 12 条目映射 6 plugin | → XcodeGen 自动生成，无重复 |
| **添加文件繁琐** | → 放对目录自动发现 |

### 1.2 最终 target 清单（13 个）

| Target | 类型 | 说明 |
|--------|------|------|
| DavyWhisper | application | 主 app |
| davywhisper-cli | tool | CLI 工具，嵌入 app bundle |
| DavyWhisperTests | bundle.unit-test | 单元测试 |
| WebhookPlugin | bundle | 嵌入 app |
| Qwen3Plugin | bundle | 嵌入 app，依赖 mlx-audio-swift |
| WhisperKitPlugin | bundle | 嵌入 app，依赖 WhisperKit |
| DeepgramPlugin | bundle | 嵌入 app |
| LiveTranscriptPlugin | bundle | 嵌入 app |
| ElevenLabsPlugin | bundle | 嵌入 app |
| GLMPlugin | bundle | 嵌入 app |
| KimiPlugin | bundle | 嵌入 app |
| MiniMaxPlugin | bundle | 嵌入 app |
| QwenLLMPlugin | bundle | 嵌入 app |

### 1.3 最终 Build Configuration

2 个配置（AppStore 配置已移除，fork 不需要）:

| 配置 | Bundle ID | 签名 |
|------|-----------|------|
| Debug | com.davywhisper.mac.dev | Automatic |
| Release | com.davywhisper.mac | Automatic |

### 1.4 最终 App Embed 结构

```
DavyWhisper.app/
  Contents/
    MacOS/
      DavyWhisper           # 主二进制
    Frameworks/
      DavyWhisperPluginSDK.framework/
    Resources/
      davywhisper-cli        # CLI 工具
      WebhookPlugin.bundle/  # 10 个插件
      Qwen3Plugin.bundle/
      WhisperKitPlugin.bundle/
      DeepgramPlugin.bundle/
      LiveTranscriptPlugin.bundle/
      ElevenLabsPlugin.bundle/
      GLMPlugin.bundle/
      KimiPlugin.bundle/
      MiniMaxPlugin.bundle/
      QwenLLMPlugin.bundle/
```

> 注意：插件在 Resources/ 而非 PlugIns/。PluginManager 已更新为同时扫描两个目录。

---

## 2. 已完成的变更

| 文件 | 操作 | 状态 |
|------|------|------|
| `project.yml` | **新建** 344 行 | ✅ |
| `Plugins/project.yml` | **删除** | ✅ |
| `Plugins/DavyWhisperPlugins.xcodeproj/` | **删除** | ✅ |
| `.bak/.pre_plugin_add*` | **删除** 3 个备份文件 | ✅ |
| `scripts/generate-projects.sh` | **新建** | ✅ |
| `.gitignore` | **修改** 添加 pbxproj 忽略规则 | ✅ |
| `CLAUDE.md` | **修改** 添加 XcodeGen 构建流程 | ✅ |
| `CodeSigning.xcconfig` | **修改** bundle ID | ✅ |
| `Info.plist` | **修改** 移除 Sparkle keys, de→zh-Hans | ✅ |
| `PluginManager.swift` | **修改** 添加 Resources/ 扫描 | ✅ |
| `AudioRecorderView.swift` | **修改** .accent→Color.accentColor | ✅ |
| `WidgetDataService.swift` | **删除** 死代码 | ✅ |
| 7 个插件 xcstrings | **修改** de→zh-Hans | ✅ |

---

## 3. 使用方式

### 生成 Xcode 项目
```bash
./scripts/generate-projects.sh
# 或直接: xcodegen generate
```

### 添加新源文件
放入正确的源目录即可，XcodeGen 自动发现。

### 添加新插件
在 `project.yml` 的 `targets:` 下添加:
```yaml
  NewPlugin:
    type: bundle
    platform: macOS
    sources:
      - Plugins/NewPlugin
    dependencies:
      - package: DavyWhisperPluginSDK
    settings:
      base:
        SWIFT_VERSION: "6.0"
        MACOSX_DEPLOYMENT_TARGET: "14.0"
        GENERATE_INFOPLIST_FILE: YES
        PRODUCT_BUNDLE_IDENTIFIER: "com.davywhisper.newplugin"
        WRAPPER_EXTENSION: bundle
        SKIP_INSTALL: YES
```
然后在 DavyWhisper target 的 dependencies 中添加 `- target: NewPlugin` + `embed: true`。

---

## 4. 收益对比

| 指标 | 迁移前 | 迁移后 |
|------|--------|--------|
| 项目定义文件 | 5707 行 pbxproj | 344 行 YAML + 自动生成 |
| 死 target | 19 个 | 0 |
| 添加新源文件 | 手动编辑 pbxproj 多处 | 放对目录，自动发现 |
| 添加新 plugin | 手动编辑 pbxproj + 注册 | YAML 中加一个 target 块（~10 行） |
| 备份文件 | 3 个 | 0（不再需要） |
| pbxproj 冲突风险 | 高（多人编辑） | 低（生成文件不入 git） |
| Embed 重复 bug | 12 条目映射 6 plugin | 自动生成，无重复 |
