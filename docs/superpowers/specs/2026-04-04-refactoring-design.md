# DavyWhisper v1.x 重构设计

**日期:** 2026-04-04
**状态:** 草案 (v2 — 已修复 spec review 发现的 14 个问题)
**作者:** Claude Code（brainstorming 会议产出）
**审核:** spec-document-reviewer（14 个问题，全部已修复）

---

## 1. 背景

DavyWhisper 是一个 macOS 菜单栏语音转文字应用，fork 自 TypeWhisper（德语 → 简体中文）。Fork 阶段 1-6 已完成。代码库现状：

- **~35,000 行** Swift，**144 个文件**
- **97 个主 App** Swift 文件，**36 个 Service**，**14 个 ViewModel**，**30 个 View**
- **7 个源码插件**（`Plugins/` 目录下）：WhisperKit、Deepgram、ElevenLabs、Paraformer、Qwen3、OpenAICompatible、LiveTranscript
- **3 个仅下载的 LLM 插件**（仅存在于 `plugins.json`）：GLM、Kimi、MiniMax（无源码目录）
- **~330 个单元测试**全部通过，覆盖率估算约 8-9%（参考 testing-framework-design.md 基线）
- **9 个 Settings Tab**（已在早期阶段从 14 合并到 9）

**已验证的插件 providerId**（来自源码）：

| 插件 | `providerId` |
|------|-------------|
| WhisperKit | `"whisper"` |
| Paraformer | `"paraformer"` |
| Qwen3 | `"qwen3"` |
| Deepgram | `"deepgram"` |
| ElevenLabs | `"elevenlabs"` |

三个关键差距：

1. **中文 ASR 准确率**：Paraformer 插件代码已存在，但不是默认引擎。WhisperKit（中文 CER ~8-10%）仍是默认选择。目标：~2-3% CER。
2. **插件注册表膨胀**：`plugins.json` 仍包含 WebhookPlugin（仅可下载）和 3 个独立的 LLM 插件。需要清理并统一 LLM 插件。
3. **测试覆盖率**：~8-9% 远低于 75% 稳定性合约目标。

---

## 2. 目标

| 维度 | 当前状态 | 目标 |
|------|---------|------|
| 中文 ASR 准确率 | ~8-10% CER（WhisperKit base） | ~2-3% CER（Paraformer） |
| 开箱即用体验 | 需要下载模型 | 立即可用（151MB 内置） |
| 默认引擎 | 无（全新安装时为 nil） | Paraformer |
| plugins.json 中的可下载插件 | 9 个条目 | 5 个条目（移除 Webhook + 3 个 LLM） |
| LLM 提供商 | 3 个独立可下载插件 | 1 个统一的 OpenAICompatiblePlugin（含预设） |
| Settings Tab 数量 | 9（已合并） | 9（无需变更） |
| 测试覆盖率 | ~8-9%（实测基线） | >=75%（CI 门禁） |

---

## 3. 执行模型

**P9 Tech Lead 编排器**管理三条工作线。关键路径定序：C 线（中文体验）作为关键路径先跑，完成后 A 线和 B 线并行。

```
Phase 0: 基线 — 测量当前测试覆盖率
    |
    v
Phase 1: C 线（关键路径 — 中文 ASR 体验）
    ├── C1: ModelManager 默认引擎切换
    ├── C2: Profile 迁移
    ├── C3: 模型打包
    └── C4: 端到端验证
    |
    v
Phase 2: A 线 + B 线（并行）
    ├── A 线: 简化（插件清理、LLM 统一）
    └── B 线: 测试覆盖率 >=75% CI 门禁
```

**C 线必须先完成的原因**：A 线修改 `plugins.json` 和插件发现逻辑，C 线修改 `ModelManagerService` 默认引擎选择。同时跑会冒着 `SettingsView.swift`、`project.yml`、`PluginManager.swift` 等共享文件合并冲突的风险。C 线先完成为 A 线建立稳定基线。

### 模块级 TDD

每个模块的变更遵循此循环：

1. **Red**：先写该模块的全部测试（覆盖当前行为 + 预期新行为）
2. **Green**：实现变更直到所有测试通过
3. **Refactor**：在模块内清理代码
4. **Gate**：模块覆盖率必须达标后才允许合入

适用于：ModelManagerService、ProfileService、OpenAICompatiblePlugin、以及本次重构涉及的所有其他模块。

---

## 4. C 线：中文体验（关键路径）

### C1: ModelManager — 默认引擎切换

**模块**：`DavyWhisper/Services/ModelManagerService.swift`

**当前行为**：`selectedProviderId` 从 `UserDefaults.standard.string(forKey: providerKey)` 加载。全新安装时返回 `nil`——没有选择任何引擎，用户必须手动选择。

**TDD 方式**：先写测试断言默认引擎选择逻辑，然后添加 Paraformer 作为硬编码兜底。

**变更**：
- 在 `ModelManagerService.init()` 中添加兜底逻辑：当 `selectedProviderId` 为 nil（全新安装）时，设置为 `"paraformer"` 并持久化到 UserDefaults
- 添加常量 `static let defaultProviderId = "paraformer"` 到 `ModelManagerService`
- 引擎选择通过 UserDefaults 跨重启持久化（已有逻辑，无需变更）
- WhisperKit（`"whisper"`）仍可手动选择用于英文/翻译场景

### C2: ProfileService — 强制迁移

**模块**：`DavyWhisper/Services/ProfileService.swift`

**TDD 方式**：先写迁移逻辑测试（检测旧 WhisperKit override → 迁移到 Paraformer → 通知用户）。

**变更**：
- 升级后首次启动，扫描所有 `engineOverride == "whisper"` 的 Profile（WhisperKit 的实际 `providerId` 是 `"whisper"`，不是 `"WhisperKit"`）
- 将这些 override 迁移为 `"paraformer"`
- 向用户展示一次性通知说明引擎变更
- 保留所有其他 Profile 设置（语言、Prompt 等）
- 迁移只执行一次，由 `UserDefaults` 标志位守护（例如 `didMigrateDefaultEngine_v1`）

### C3: 模型打包 — Bundle 优先策略

**模块**：`Plugins/ParaformerPlugin/ParaformerPlugin.swift`、`Plugins/ParaformerPlugin/SherpaOnnx.swift`

**变更**：
- 模型文件已存在于 `DavyWhisper/Resources/ParaformerModel/`（79MB ASR + 72MB 标点 = 151MB）
- 在 `ParaformerPlugin` 中实现 Bundle 优先模型解析：
  1. 先检查用户 Application Support 目录（`~/Library/Application Support/DavyWhisper/PluginData/com.davywhisper.paraformer/`）是否有下载/更新的模型
  2. 未找到则回退到 `Bundle.main.url(forResource: "ParaformerModel", withExtension: nil)`
  3. 用户目录模型覆盖内置模型（允许不重装 App 即可更新）
- 移除首次启动时的强制下载要求

### C4: 端到端验证

**验收标准**：
- 全新安装 → 启动 → 立即转录中文音频 → CER < 3%
- 首次转录无需网络
- 已有 Profile 迁移到 Paraformer 并弹出通知
- WhisperKit 仍可手动选择

---

## 5. A 线：简化

### A1: 从 plugins.json 移除 WebhookPlugin

**范围**：WebhookPlugin 在 `Plugins/` 下没有源码目录——仅作为可下载条目存在于 `DavyWhisper/Resources/plugins.json`（第 71-85 行，ID: `com.davywhisper.webhook`）。WatchFolder 插件条目已不存在于 `plugins.json` 中——之前已移除。

**TDD 方式**：写测试断言清理后 plugins.json 不包含 webhook 条目。写测试断言源码中没有对 `com.davywhisper.webhook` 的引用。

**变更**：
- 从 `plugins.json` 移除 `com.davywhisper.webhook` 条目
- Grep 搜索源码中所有对 webhook 插件的引用并移除
- 无需清理 Settings UI（WebhookPlugin 从未集成到 Settings Tab）

### A2: 删除 AudioDucking（确认后执行）

**TDD 方式**：Grep 代码库中所有对 AudioDucking 的引用。如果没有 Service、View 或用户可见设置依赖它，则执行完整清理。

**前提**：确认没有用户可见设置或内部 Service 依赖 AudioDucking 后才可删除。

### A3: LLM 统一 — 将可下载 LLM 插件合并到 OpenAICompatiblePlugin

**范围**：GLM、Kimi、MiniMax 三个 LLM 插件仅作为可下载条目存在于 `plugins.json`——`Plugins/` 下**没有源码目录**。工作内容：(1) 移除它们的 `plugins.json` 条目，(2) 在现有 `Plugins/OpenAICompatiblePlugin/` 中添加内置预设，(3) 迁移用户 API Key 配置。

**模块**：`Plugins/OpenAICompatiblePlugin/OpenAICompatiblePlugin.swift`

**TDD 方式**：先写测试覆盖预设选择、API URL 构造、每个预设的 API Key 获取。

**变更**：
- 在 `OpenAICompatiblePlugin` 中添加内置 LLM 预设：

  | 预设名称 | 旧插件 ID | Base URL | API Key 存储 |
  |---------|----------|----------|-------------|
  | GLM（智谱 AI） | `com.davywhisper.glm` | `open.bigmodel.cn/api/paas/v4` | Keychain |
  | Kimi（月之暗面） | `com.davywhisper.kimi` | `api.moonshot.cn/v1` | Keychain |
  | MiniMax | `com.davywhisper.minimax` | `api.minimax.chat/v1` | Keychain |

- 从 `plugins.json` 移除 `com.davywhisper.glm`、`com.davywhisper.kimi`、`com.davywhisper.minimax` 条目
- 保留每个提供商的已有 Keychain 条目（用户无需重新输入 API Key）
- 添加"自定义 OpenAI Compatible"选项，支持任意其他提供商（base URL + model name）
- 更新 Settings UI 显示统一的提供商选择器（含预设下拉菜单）

### A4: Settings Tab 合并 — 已完成

Settings Tab 已在早期阶段从 14 合并到 9。当前 Tab（已从 `SettingsView.swift` 验证）：

`general, recording, fileTranscription, history, dictionary, profiles, prompts, integrations, advanced`

**无需额外工作。** 此步骤标记为已完成。

---

## 6. B 线：测试覆盖率（CI 门禁）

### 基线测量

重构开始之前：
1. 运行 `xcodebuild test -project DavyWhisper.xcodeproj -scheme DavyWhisper -enableCodeCoverage YES`
2. 提取各模块真实覆盖率数据
3. 在此 spec 中记录基线

### 覆盖率目标

**基线**：重构开始前必须用 `xcodebuild test -enableCodeCoverage YES` 实测。参考 testing-framework-design.md 估算：整体 ~8%，Service ~29%，ViewModel ~22%。

| 模块 | 当前（估算） | 目标 |
|------|------------|------|
| ModelManagerService | ~10% | >=80% |
| ProfileService | ~40% | >=80% |
| HTTPServer/Handlers | ~40% | >=85% |
| AudioRecordingService | ~5% | >=70% |
| PluginManager | ~15% | >=75% |
| DictationViewModel | ~10% | >=80% |
| PromptProcessingService | ~20% | >=80% |
| SettingsViewModel | ~10% | >=80% |
| 整体 | ~8-9% | >=75% |

### CI 门禁规则

每个 PR 必须达到 >=75% 整体覆盖率才允许合入。执行方式：
- 在 CI 中运行 `xcodebuild test -enableCodeCoverage YES`
- 解析覆盖率报告
- 未达标则阻止合入

### 测试基础设施

现有测试基础设施足够使用：
- `TestServiceContainer` 用于依赖注入
- `DavyWhisperTests/Mocks/` 中的 Mock 实现
- `DavyWhisper/Protocols/` 中的协议定义
- `UserDefaultsProviding` 协议用于测试隔离

---

## 7. 版本策略

版本号在 C 线完成后根据实际行为差异决定。选项：

- **1.x.z**：如果变更对用户透明（API 不变，仅增强默认值）
- **2.0.0-pre**：如果 HTTP API 或插件接口发生破坏性变更
- **1.x "zh-enhanced"**：面向中国市场的标签化构建

决策推迟到 C 线完成后评估。

---

## 8. 数据迁移

| 数据类型 | 迁移策略 |
|---------|---------|
| Profile 引擎 override | 强制迁移 `engineOverride == "whisper"` → `"paraformer"`，通知用户 |
| 插件特定设置 | 直接删除（WebhookPlugin 无持久化用户数据） |
| LLM 提供商选择 | 将旧插件 ID 映射到新的统一预设 ID（见下方映射表） |
| 历史记录 | 不变（历史记录中的引擎名称仅为展示信息） |
| 词典/片段 | 不变 |

**LLM 插件 ID 迁移映射表**：

| 旧插件 ID | 新预设 Key | API Key 位置 |
|----------|-----------|-------------|
| `com.davywhisper.glm` | `glm`（OpenAICompatiblePlugin 中的预设） | Keychain — 保留已有 Key |
| `com.davywhisper.kimi` | `kimi`（OpenAICompatiblePlugin 中的预设） | Keychain — 保留已有 Key |
| `com.davywhisper.minimax` | `minimax`（OpenAICompatiblePlugin 中的预设） | Keychain — 保留已有 Key |

---

## 9. 风险矩阵

| 风险 | 可能性 | 影响 | 缓解措施 |
|------|-------|------|---------|
| Paraformer 151MB 打包增加下载体积 | 高 | 中 | GitHub Releases 无大小限制；对中国用户可接受的权衡 |
| Profile 迁移破坏用户工作流 | 低 | 高 | 先写迁移测试；展示带撤销选项的通知 |
| LLM 统一破坏已有 API Key 配置 | 中 | 中 | 保留 Keychain 条目；将旧插件 ID 映射到新预设 Key |
| 测试覆盖率门禁阻塞 PR 流速 | 中 | 中 | 从基线开始；逐步提高阈值 |
| Bundle 优先模型解析选错模型 | 低 | 高 | 为解析顺序写测试（用户目录 > Bundle）；加日志 |

---

## 10. 成功标准

1. **中文 ASR**：全新安装转录中文音频 CER < 3%，无需下载
2. **默认引擎**：全新安装自动选择 Paraformer（无 nil 状态）
3. **插件注册表清理**：WebhookPlugin + 3 个独立 LLM 插件已从 plugins.json 移除
4. **LLM 统一**：OpenAICompatiblePlugin 通过预设处理 GLM/Kimi/MiniMax
5. **测试覆盖率**：整体 >=75%，CI 门禁生效
6. **已有测试**：~330+ 测试持续全部通过
7. **HTTP API**：所有 `/v1/*` 端点不变且通过测试
8. **无回归**：Profile（已迁移）、历史记录、词典、片段全部功能正常

---

## 附录 A：文件影响估算

### C 线文件

| 文件 | 变更类型 |
|------|---------|
| `DavyWhisper/Services/ModelManagerService.swift` | 添加 defaultProviderId 兜底 |
| `DavyWhisper/Services/ProfileService.swift` | 添加引擎 override 迁移逻辑 |
| `Plugins/ParaformerPlugin/ParaformerPlugin.swift` | 添加 Bundle 优先模型解析 |
| `DavyWhisper/Resources/ParaformerModel/` | 已包含内置模型 |
| `DavyWhisperTests/` | 新增默认引擎 + 迁移测试 |

### A 线文件

| 文件 | 变更类型 |
|------|---------|
| `DavyWhisper/Resources/plugins.json` | 移除 webhook + LLM 插件条目 |
| `Plugins/OpenAICompatiblePlugin/OpenAICompatiblePlugin.swift` | 添加 GLM/Kimi/MiniMax 预设 |
| `DavyWhisper/ViewModels/SettingsViewModel.swift` | 更新提供商选择器 |
| `DavyWhisperTests/` | 预设选择 + 迁移测试 |

### B 线文件

| 文件 | 变更类型 |
|------|---------|
| `DavyWhisperTests/` | 扩展新测试文件 |
| `.github/workflows/` | 添加覆盖率门禁到 CI |

## 附录 B：引用的已有文档

| 文档 | 路径 | 相关性 |
|------|------|--------|
| DavyWhisper 设计 | `docs/superpowers/specs/2026-03-31-davywhisper-design.md` | 原始 fork spec |
| 测试框架 | `docs/superpowers/specs/2026-04-03-testing-framework-design.md` | 测试基础设施 |
| 简化计划 v2 | `docs/simplification-plan-v2.md` | A 线参考来源 |
| Paraformer 集成 | `docs/paraformer-integration-plan.md` | C 线参考来源 |
| 模型集成 | `docs/model-integration-plan.md` | 模型打包 |
| 整合优化 | `docs/consolidated-optimization-plan.md` | 综合计划 |
