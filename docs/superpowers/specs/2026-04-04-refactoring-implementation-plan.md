# DavyWhisper v1.x 重构 — 实施计划

**基于 spec:** `docs/superpowers/specs/2026-04-04-refactoring-design.md`
**日期:** 2026-04-04

---

## 代码实际情况（影响实施细节）

| 发现 | 影响 |
|------|------|
| `OpenAICompatiblePlugin` 已含 GLM/Kimi/MiniMax/Qwen/DeepSeek 预设 | 需要拆分，不是从零开始 |
| SDK 已有 `PluginOpenAIChatHelper`（OpenAI 兼容请求工具） | 新 LLM 插件直接复用 |
| SDK 已有 `LLMProviderPlugin` 协议 + `PluginManifest` | 新插件只需实现协议 |
| `PluginManager` 硬编码了编译插件列表 | 添加新插件必须更新此列表 |
| `ParaformerPlugin.resolveModelDir()` 已是 Bundle→用户目录 两级查找 | C3 工作量比预期小 |
| `ModelManagerService.selectedProviderId` 全新安装为 nil | C1 需要添加兜底默认值 |
| `project.yml` Sources 列表直接引用 `Plugins/XXXPlugin/` | 新增插件需添加 source path |

---

## Phase 0: 基线测量

**目标**: 获取真实覆盖率数据作为后续 CI gate 基线

### F0-1: 运行覆盖率测试
```
xcodebuild test -project DavyWhisper.xcodeproj -scheme DavyWhisper \
  -destination 'platform=macOS,arch=arm64' \
  -enableCodeCoverage YES \
  CODE_SIGN_IDENTITY='-' CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
  2>&1 | tee build-release/coverage-baseline.log
```

### F0-2: 提取覆盖率
```
xcrun xccov view --report $(find ~/Library/Developer/Xcode/DerivedData -name "*.xcresult" | head -1) \
  | grep -E "(DavyWhisper|Overall)" | head -30
```

### F0-3: 记录基线
- 将各模块覆盖率写入 spec 的 Section 6 表格
- 提交 commit: `docs: 记录测试覆盖率基线`

---

## Phase 1: C 线（关键路径 — 中文 ASR 体验）

### F1-1: ModelManager 默认引擎

**当前代码**: `ModelManagerService.swift:46` — `selectedProviderId = UserDefaults.standard.string(forKey: providerKey)`, nil 时无兜底

**TDD — Red**:
1. 创建 `DavyWhisperTests/Services/ModelManagerDefaultEngineTests.swift`
2. 写测试:
   - `test_defaultEngine_nil_fallsBackToParaformer` — 模拟 nil UserDefaults，断言 selectedProviderId 为 "paraformer"
   - `test_defaultEngine_persistsToUserDefaults` — 断言兜底值写入 UserDefaults
   - `test_defaultEngine_existingUser_notOverridden` — 模拟已有 "whisper"，断言不变
   - `test_defaultEngineConstant_isParaformer` — 断言 `defaultProviderId == "paraformer"`

**TDD — Green**:
1. 在 `ModelManagerService` 添加 `static let defaultProviderId = "paraformer"`
2. 修改 `init()`:
   ```swift
   let stored = UserDefaults.standard.string(forKey: providerKey)
   self.selectedProviderId = stored ?? Self.defaultProviderId
   if stored == nil {
       UserDefaults.standard.set(Self.defaultProviderId, forKey: providerKey)
   }
   ```

**TDD — Refactor**: 无需重构（变更极小）

**Gate**: 4 个新测试全部通过 + `xcodebuild test` 无回归

**Commit**: `feat: ModelManager 默认选择 Paraformer 引擎`

---

### F1-2: Profile 迁移

**当前代码**: `Profile.swift:16` — `var engineOverride: String?` 是 SwiftData 持久化属性

**TDD — Red**:
1. 创建 `DavyWhisperTests/Services/ProfileEngineMigrationTests.swift`
2. 写测试:
   - `test_migrate_whisperOverride_becomesParaformer` — Profile with engineOverride="whisper" → "paraformer"
   - `test_migrate_onlyRunsOnce` — 调用两次，第二次无操作
   - `test_migrate_noOverride_noAction` — engineOverride=nil 不变
   - `test_migrate_nonWhisperOverride_preserved` — engineOverride="deepgram" 不变
   - `test_migrate_setsUserDefaultsFlag` — 迁移后设置 `didMigrateDefaultEngine_v1 = true`

**TDD — Green**:
1. 在 `ProfileService` 添加 `migrateDefaultEngine()` 方法:
   ```swift
   func migrateDefaultEngine() {
       guard !UserDefaults.standard.bool(forKey: "didMigrateDefaultEngine_v1") else { return }
       // fetch all profiles, migrate engineOverride == "whisper" → "paraformer"
       UserDefaults.standard.set(true, forKey: "didMigrateDefaultEngine_v1")
   }
   ```
2. 在 `DavyWhisperApp.swift` 或 `ServiceContainer.init()` 中调用

**TDD — Refactor**: 迁移逻辑可提取到 `MigrationService`（如果后续还有更多迁移）

**Gate**: 5 个新测试通过 + 已有 ProfileServiceTests 不回归

**Commit**: `feat: Profile 迁移 WhisperKit override 到 Paraformer`

---

### F1-3: Bundle 优先模型路径验证

**当前代码**: `ParaformerPlugin.swift:122-136` — 已实现 Bundle→用户目录两级查找

**变更**:
- 验证 `DavyWhisper/Resources/ParaformerModel/` 包含完整模型文件（model.int8.onnx + tokens.txt + PunctuationModel/）
- 验证 `project.yml` 已将 ParaformerModel 排除编译但包含为 resource
- 如果当前逻辑已满足 spec 要求（Bundle first → 用户目录 fallback），**则无需代码变更**

**TDD — Red/Green**:
1. 创建 `DavyWhisperTests/Integration/ParaformerBundleResolutionTests.swift`
2. 写测试:
   - `test_bundledModel_existsAtResourcePath` — 断言 Bundle 包含 ParaformerModel
   - `test_resolveModelDir_returnsBundledPath` — 无用户目录模型时返回 Bundle 路径
   - `test_resolveModelDir_userDirOverridesBundle` — 用户目录有模型时优先返回

**Gate**: 3 个测试通过

**Commit**: `test: Paraformer Bundle 优先模型解析验证`

---

### F1-4: 端到端验证

**手动测试清单**:
1. `xcodegen generate` → `xcodebuild build` → 确认 ParaformerModel 被打包进 .app
2. 清除 UserDefaults（模拟全新安装）→ 启动 App → 确认默认引擎为 Paraformer
3. 转录一段中文音频 → 确认 CER < 3%
4. 创建 engineOverride="whisper" 的 Profile → 重启 → 确认迁移为 "paraformer"
5. 手动切换到 WhisperKit → 确认仍可用

**Gate**: 5 项手动测试全部通过 + `xcodebuild test` 全部通过

**Commit**: `test: C 线端到端验证通过`

---

## Phase 2: A 线 + B 线（并行）

### A 线: 简化

#### F2-A1: 移除 WebhookPlugin

**TDD — Red**:
1. 写测试断言 plugins.json 无 webhook 条目
2. 写测试断言源码无 `com.davywhisper.webhook` 引用

**TDD — Green**:
1. 编辑 `plugins.json`，移除 `com.davywhisper.webhook` 条目
2. Grep 清理所有 webhook 引用

**Gate**: 2 个测试通过

**Commit**: `chore: 从 plugins.json 移除 WebhookPlugin`

---

#### F2-A2: AudioDucking 确认

**前置**: Grep 搜索 AudioDucking 引用，确认无依赖后删除或保留

---

#### F2-A3: LLM 独立插件（4 个）

**关键架构决策**: 当前 `OpenAICompatiblePlugin` 已含 GLM/Kimi/MiniMax 预设。用户要求 4 个独立插件。

**方案**: 
- 保留 `OpenAICompatiblePlugin`（用于 DeepSeek、自定义 provider）
- 从 OpenAICompatiblePlugin 的预设中提取 GLM/Kimi/MiniMax 配置
- 新建 4 个独立插件目录，每个复用 SDK 的 `PluginOpenAIChatHelper`

**每个插件的文件结构**:
```
Plugins/GLMPlugin/
├── GLMPlugin.swift              # 实现 LLMProviderPlugin 协议
├── manifest_GLMPlugin.json      # 插件 manifest
└── Localizable.xcstrings        # 本地化字符串

Plugins/KimiPlugin/
├── KimiPlugin.swift
├── manifest_KimiPlugin.json
└── Localizable.xcstrings

Plugins/MiniMaxPlugin/
├── MiniMaxPlugin.swift
├── manifest_MiniMaxPlugin.json
└── Localizable.xcstrings

Plugins/BailianPlugin/
├── BailianPlugin.swift
├── manifest_BailianPlugin.json
└── Localizable.xcstrings
```

**每个插件实现模板**（以 GLM 为例）:
```swift
@objc(GLMPlugin)
final class GLMPlugin: NSObject, LLMProviderPlugin, @unchecked Sendable {
    static let pluginId = "com.davywhisper.glm"
    static let pluginName = "GLM"
    
    private var host: HostServices?
    private let baseURL = "https://open.bigmodel.cn/api/paas/v4"
    private let models: [PluginModelInfo] = [
        PluginModelInfo(id: "glm-4-flash", displayName: "GLM-4-Flash", ...),
        PluginModelInfo(id: "glm-4-air", displayName: "GLM-4-Air", ...),
        ...
    ]
    
    // activate/deactivate/settingsView 同 OpenAICompatiblePlugin 模式
    // process() 调用 host?.loadSecret + PluginOpenAIChatHelper
}
```

**TDD — 每个插件的 Red 阶段**:

创建 `DavyWhisperTests/Plugins/GLMPluginTests.swift`（其他 3 个类似）:
- `test_pluginRegisters_withCorrectId`
- `test_apiKeyStoredInKeychain`
- `test_apiKeyLoadedFromKeychain`
- `test_supportedModels_returnedList`
- `test_process_constructsCorrectRequest`
- `test_process_handlesMissingApiKey`
- `test_process_handlesNetworkError`
- `test_process_parsesResponse`
- `test_isAvailable_trueWhenApiKeySet`
- `test_isAvailable_falseWhenNoApiKey`
- `test_settingsView_returnsApiKeyInputAndModelSelector`

4 个插件 × 11 个测试 = **44 个新测试**

**TDD — Green 阶段**:
1. 创建 4 个插件源码目录 + Swift 实现
2. 创建 4 个 manifest JSON 文件
3. 更新 `project.yml` 添加 4 个 source path
4. 更新 `PluginManager.pluginNames` 添加 4 个插件名
5. 更新 `plugins.json`：更新 GLM/Kimi/MiniMax 条目，新增百炼条目

**TDD — Refactor**:
- 从 4 个插件提取共用逻辑到 SDK（如果重复代码超过阈值）
- 考虑在 SDK 中添加 `OpenAICompatibleLLMBase` 基类

**Gate**: 44 个新测试全部通过 + `xcodebuild test` 无回归

**Commits**:
1. `feat: GLMPlugin 独立插件完整实现`
2. `feat: KimiPlugin 独立插件完整实现`
3. `feat: MiniMaxPlugin 独立插件完整实现`
4. `feat: BailianPlugin 独立插件完整实现`
5. `chore: 更新 PluginManager 注册 4 个新 LLM 插件`
6. `chore: 更新 plugins.json 添加百炼、更新 GLM/Kimi/MiniMax`

---

### B 线: 测试覆盖率（与 A 线并行）

#### F2-B1: 核心模块测试补全

**优先级排序**（按 spec 覆盖率目标）:

| 模块 | 目标 | 关键功能需测试 |
|------|------|-------------|
| ModelManagerService | >=80% | 默认引擎、引擎选择持久化、auto-unload、transcribe 调度 |
| ProfileService | >=80% | CRUD、匹配逻辑、迁移 |
| HTTPServer/Handlers | >=85% | 10 个端点、multipart 解析、错误响应 |
| DictationViewModel | >=80% | 录音开始/停止、短句检测、文本插入 |
| SettingsViewModel | >=80% | 设置读写、引擎选择、LLM 提供商选择 |
| PromptProcessingService | >=80% | provider 路由、memory 注入、prompt 构造 |
| PluginManager | >=75% | 编译插件加载、LLM provider 查找、enabled 状态 |
| AudioRecordingService | >=70% | 权限、录音开始/停止、buffer 管理 |

**每个功能按 TDD 循环**: Red → Green → Refactor → Gate

#### F2-B2: CI 覆盖率门禁

1. 创建/更新 `.github/workflows/test.yml`:
   ```yaml
   - name: Run tests with coverage
     run: |
       xcodebuild test -project DavyWhisper.xcodeproj -scheme DavyWhisper \
         -destination 'platform=macOS,arch=arm64' \
         -enableCodeCoverage YES \
         CODE_SIGN_IDENTITY='-' CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO
   - name: Check coverage
     run: |
       COVERAGE=$(xcrun xccov view --report ... | grep "Overall" | awk '{print $1}' | sed 's/%//')
       echo "Coverage: ${COVERAGE}%"
       if (( $(echo "$COVERAGE < 75" | bc -l) )); then
         echo "FAIL: Coverage ${COVERAGE}% < 75%"
         exit 1
       fi
   ```

**Gate**: CI 绿 + 覆盖率 >=75%

---

## 执行顺序汇总

```
Phase 0 (基线)
  F0-1 → F0-2 → F0-3
  
Phase 1 (C 线 — 串行)
  F1-1 (ModelManager 默认) → F1-2 (Profile 迁移) → F1-3 (Bundle 验证) → F1-4 (E2E)
  
Phase 2 (A + B — 并行)
  A 线:  F2-A1 (Webhook) → F2-A2 (AudioDucking) → F2-A3 (4 个 LLM 插件)
  B 线:  F2-B1 (核心模块测试) → F2-B2 (CI 门禁)
```

## 预估工作量

| 功能 | 新增测试数 | 代码变更行数 | 复杂度 |
|------|----------|------------|--------|
| F1-1 ModelManager 默认 | 4 | ~10 | 低 |
| F1-2 Profile 迁移 | 5 | ~30 | 低 |
| F1-3 Bundle 验证 | 3 | 0 | 低 |
| F2-A1 Webhook 清理 | 2 | ~5 | 低 |
| F2-A2 AudioDucking | 1-2 | ~0-20 | 低 |
| F2-A3 LLM × 4 插件 | 44 | ~800 | 高 |
| F2-B1 核心模块测试 | ~200+ | 0（纯测试） | 高 |
| F2-B2 CI 门禁 | 0 | ~30 | 低 |
| **合计** | **~260** | **~900** | |
