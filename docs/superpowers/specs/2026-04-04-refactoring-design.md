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
- **百炼（阿里云 DashScope）** 尚未集成
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
2. **LLM 插件不完整**：`plugins.json` 中 GLM、Kimi、MiniMax 三个插件仅有条目但**没有源码实现**，无法真正使用。需要创建完整的源码插件，并新增百炼（阿里云 DashScope）插件。
3. **测试覆盖率**：~8-9% 远低于 75% 稳定性合约目标。

---

## 2. 目标

| 维度 | 当前状态 | 目标 |
|------|---------|------|
| 中文 ASR 准确率 | ~8-10% CER（WhisperKit base） | ~2-3% CER（Paraformer） |
| 开箱即用体验 | 需要下载模型 | 立即可用（151MB 内置） |
| 默认引擎 | 无（全新安装时为 nil） | Paraformer |
| plugins.json 中的可下载插件 | 9 个条目 | 8 个条目（移除 Webhook，新增百炼） |
| LLM 提供商 | 3 个仅有条目无源码 | 4 个完整可用的独立插件（GLM、Kimi、MiniMax、百炼） |
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

### 功能级 TDD

每一个功能（不仅是模块）都必须经过完整的 TDD 循环：

1. **Red**：为该功能写全部测试（覆盖正常路径 + 边界条件 + 错误处理）
2. **Green**：实现功能直到所有测试通过
3. **Refactor**：清理代码，消除重复
4. **Gate**：该功能测试覆盖率达标后才允许合入

**功能粒度定义**：一个功能是一个可独立验证的行为单元。例如：
- "ModelManager 在全新安装时默认选择 Paraformer" → 1 个功能，3+ 个测试（nil→默认、持久化、重启后保持）
- "Profile 迁移将 WhisperKit override 改为 Paraformer" → 1 个功能，4+ 个测试（匹配 "whisper"、迁移为 "paraformer"、只迁移一次、无 override 时不报错）
- "GLM 插件完成 Chat Completion 请求" → 1 个功能，5+ 个测试（正常请求、API Key 缺失、网络超时、流式响应、错误 JSON）

适用于本次重构涉及的所有功能。

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

### A3: LLM 插件 — 4 个独立完整可用的中文大模型插件

**要求**：GLM、Kimi、MiniMax、百炼四个中文大模型插件必须**独立、完整、可用**。每个插件都有源码实现、manifest.json、Settings UI 配置入口。用户安装后填入 API Key 即可使用，无需额外配置。

**范围**：当前 GLM、Kimi、MiniMax 在 `plugins.json` 中仅有下载条目，`Plugins/` 下**没有源码目录**。百炼尚未有任何条目。需要为 4 个 LLM 插件创建完整源码实现。

#### 四个 LLM 插件完整规格

**GLMPlugin（智谱 AI）**

| 项目 | 值 |
|------|---|
| 插件 ID | `com.davywhisper.glm` |
| 源码目录 | `Plugins/GLMPlugin/` |
| Base URL | `https://open.bigmodel.cn/api/paas/v4` |
| API Key 获取 | https://open.bigmodel.cn → 控制台 → API Keys |
| 默认模型 | `glm-4-flash` |
| 可选模型 | `glm-4-flash`, `glm-4-air`, `glm-4-plus`, `glm-4-long` |
| 协议兼容 | OpenAI Chat Completions 兼容 |
| Key 存储 | Keychain (`com.davywhisper.glm.apikey`) |

**KimiPlugin（月之暗面 Moonshot）**

| 项目 | 值 |
|------|---|
| 插件 ID | `com.davywhisper.kimi` |
| 源码目录 | `Plugins/KimiPlugin/` |
| Base URL | `https://api.moonshot.cn/v1` |
| API Key 获取 | https://platform.moonshot.cn → API Keys |
| 默认模型 | `moonshot-v1-auto` |
| 可选模型 | `moonshot-v1-8k`, `moonshot-v1-32k`, `moonshot-v1-128k`, `moonshot-v1-auto` |
| 协议兼容 | OpenAI Chat Completions 兼容 |
| Key 存储 | Keychain (`com.davywhisper.kimi.apikey`) |

**MiniMaxPlugin**

| 项目 | 值 |
|------|---|
| 插件 ID | `com.davywhisper.minimax` |
| 源码目录 | `Plugins/MiniMaxPlugin/` |
| Base URL | `https://api.minimax.io/v1` |
| API Key 获取 | https://platform.minimaxi.com → API Keys |
| 默认模型 | `MiniMax-Text-01` |
| 可选模型 | `MiniMax-Text-01`, `abab6.5s-chat` |
| 协议兼容 | OpenAI Chat Completions 兼容 |
| Key 存储 | Keychain (`com.davywhisper.minimax.apikey`) |

**BailianPlugin（阿里云百炼 DashScope）**

| 项目 | 值 |
|------|---|
| 插件 ID | `com.davywhisper.bailian` |
| 源码目录 | `Plugins/BailianPlugin/` |
| Base URL | `https://dashscope.aliyuncs.com/compatible-mode/v1` |
| API Key 获取 | https://dashscope.console.aliyun.com → API-KEY 管理 |
| 默认模型 | `qwen-plus` |
| 可选模型 | `qwen-plus`, `qwen-turbo`, `qwen-max`, `qwen-long` |
| 协议兼容 | OpenAI Chat Completions 兼容 |
| Key 存储 | Keychain (`com.davywhisper.bailian.apikey`) |

#### TDD 方式

每个插件按以下顺序开发：
1. **Red**：写测试覆盖插件注册、API Key 存储/读取、模型列表获取、Chat Completion 请求构造、响应解析、错误处理
2. **Green**：实现插件源码，所有测试通过
3. **Refactor**：提取共用逻辑到 SDK 或基类（4 个插件共享 OpenAI Compatible 协议）

#### 共用架构

4 个插件都兼容 OpenAI Chat Completions API，共享以下逻辑：
- 请求构造（`messages` → `POST /chat/completions`）
- 响应解析（`choices[0].message.content`）
- 流式响应处理（SSE `data:` 行解析）
- API Key Keychain 存取
- 模型列表展示

建议：在 `DavyWhisperPluginSDK` 中提供 `OpenAICompatibleLLMBase` 基类，4 个插件继承它并仅需配置 `baseURL`、`modelList`、`apiKeyKeychainId`。

#### 变更清单

- 创建 4 个插件源码目录及完整实现
- 更新 `plugins.json`：移除旧的 GLM/Kimi/MiniMax 占位条目，添加百炼条目，更新 GLM/Kimi/MiniMax 为有实际下载包的条目
- 更新 `project.yml`：添加 4 个插件 target（`GLMPlugin`、`KimiPlugin`、`MiniMaxPlugin`、`BailianPlugin`）
- 在 SDK 中添加 `OpenAICompatibleLLMBase` 基类（可选，减少重复代码）
- 每个 Settings 界面提供：API Key 输入框、模型选择下拉框、连通性测试按钮
- 为每个插件编写完整单元测试

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
| LLM 提供商选择 | 无需迁移（保留独立插件架构，新增百炼插件） |
| 历史记录 | 不变（历史记录中的引擎名称仅为展示信息） |
| 词典/片段 | 不变 |

**LLM 插件 Keychain Key 一览**（已有 Key 无需迁移）：

| 插件 | Keychain Key | 状态 |
|------|-------------|------|
| GLM | `com.davywhisper.glm.apikey` | 已有，保留 |
| Kimi | `com.davywhisper.kimi.apikey` | 已有，保留 |
| MiniMax | `com.davywhisper.minimax.apikey` | 已有，保留 |
| 百炼 | `com.davywhisper.bailian.apikey` | 新增 |

---

## 9. 风险矩阵

| 风险 | 可能性 | 影响 | 缓解措施 |
|------|-------|------|---------|
| Paraformer 151MB 打包增加下载体积 | 高 | 中 | GitHub Releases 无大小限制；对中国用户可接受的权衡 |
| Profile 迁移破坏用户工作流 | 低 | 高 | 先写迁移测试；展示带撤销选项的通知 |
| LLM 插件 API 接口变更导致请求失败 | 中 | 高 | 每个插件完整 TDD；用真实 API Key 做集成测试 |
| 测试覆盖率门禁阻塞 PR 流速 | 中 | 中 | 从基线开始；逐步提高阈值 |
| Bundle 优先模型解析选错模型 | 低 | 高 | 为解析顺序写测试（用户目录 > Bundle）；加日志 |

---

## 10. 成功标准

1. **中文 ASR**：全新安装转录中文音频 CER < 3%，无需下载
2. **默认引擎**：全新安装自动选择 Paraformer（无 nil 状态）
3. **WebhookPlugin 清理**：已从 plugins.json 移除
4. **LLM 插件完整可用**：GLM、Kimi、MiniMax、百炼 4 个插件独立、完整、安装后填 API Key 即可用
5. **每个 LLM 插件功能经过 TDD 验证**：注册、API Key 存取、模型列表、Chat Completion、流式响应、错误处理
6. **测试覆盖率**：整体 >=75%，CI 门禁生效
7. **已有测试**：~330+ 测试持续全部通过
8. **HTTP API**：所有 `/v1/*` 端点不变且通过测试
9. **无回归**：Profile（已迁移）、历史记录、词典、片段全部功能正常

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
| `DavyWhisper/Resources/plugins.json` | 移除 WebhookPlugin 条目，更新 GLM/Kimi/MiniMax 条目，新增百炼条目 |
| `Plugins/GLMPlugin/` | 新建完整源码实现 |
| `Plugins/KimiPlugin/` | 新建完整源码实现 |
| `Plugins/MiniMaxPlugin/` | 新建完整源码实现 |
| `Plugins/BailianPlugin/` | 新建完整源码实现 |
| `DavyWhisperPluginSDK/Sources/` | 可选：添加 `OpenAICompatibleLLMBase` 基类 |
| `project.yml` | 添加 4 个 LLM 插件 target |
| `DavyWhisperTests/` | 每个插件的完整单元测试 |

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
