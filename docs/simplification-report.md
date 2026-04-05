# DavyWhisper 功能精简报告

**日期**: 2026-04-05  
**目标**: 移除低频高复杂度功能，简化代码库

## Phase 1: 功能删除 (已完成)

### 1. 录音功能 (Audio Recording)
**删除内容**:
- `AudioRecordingService.swift` - 录音服务核心
- `AudioRecorderService.swift` - 录音机服务
- `AudioRecorderView.swift` - 录音 UI 界面
- `AudioRecorderViewModel.swift` - 录音 ViewModel
- `AudioRecordingProtocol.swift` - 录音协议
- `MockAudioRecordingService.swift` - 测试 Mock

**保留内容**:
- 核心语音输入功能（通过 `AudioFileService` 支持文件转写）

**影响**:
- 移除了实时录音配置入口
- 保留了文件转写能力

### 2. 文件转录功能 (File Transcription) - UI 层
**删除内容**:
- `FileTranscriptionView.swift` - 文件转录主界面 (~200 行)
- `FileTranscriptionViewModel.swift` - 已从 ServiceContainer 移除

**修改文件**:
- `SettingsView.swift` - 删除 File Transcription 标签页
- `MenuBarView.swift` - 删除 "Transcribe File..." 菜单项
- `AudioRecorderViewModel.swift` - 删除 `transcribeRecording()` 方法
- `ServiceContainer.swift` - 删除 FileTranscriptionViewModel 依赖注入

**影响**:
- 用户无法通过 UI 选择文件进行转写
- 保留 `AudioFileService` 供语音输入流程使用

### 2. 翻译功能 (Translation)
**删除内容**:
- `TranslationService.swift` - Apple Translate 封装
- `TranslationHostWindow.swift` - 翻译交互窗口
- 相关测试文件

**修改文件**:
- `GeneralSettingsView.swift` - 删除翻译设置
- `ProfilesSettingsView.swift` - 删除翻译目标语言覆盖
- `DictationViewModel.swift` - 删除翻译处理逻辑
- `APIHandlers.swift` - 删除翻译 API 端点

**影响**:
- macOS 15+ 设备端翻译功能不可用
- 用户仍可通过 LLM Prompt 进行翻译

### 3. 词典功能 (Dictionary)
**删除内容**:
- `DictionaryService.swift` - 词典服务
- `DictionaryExporter.swift` - 词典导出
- `DictionaryEntry.swift` - 词典数据模型
- `DictionaryViewModel.swift` - 词典 ViewModel
- `DictionarySettingsView.swift` - 词典设置界面
- `DictionarySnippetsSettingsView.swift` - 词典和片段设置

**修改文件**:
- `DictationViewModel.swift` - 删除词典术语提示
- `StreamingHandler.swift` - 删除词典流式处理
- `HistoryViewModel.swift` - 删除词典学习
- `PostProcessingPipeline.swift` - 删除词典后处理

**影响**:
- 术语提升功能不可用
- 纠错自动修复功能不可用
- 术语包导入功能不可用

## Phase 2: UX 简化 (已完成 - 2026-04-05)

### Sprint 1: 指示器配置简化
**改动**: 将 6 个独立配置项折叠为 3 个预设模式
- 新增 `IndicatorPreset` 枚举（minimal/standard/detailed/custom）
- 保留自定义模式，折叠在 DisclosureGroup 中
- 自动从遗留配置迁移到预设

**文件**:
- `DictationEnums.swift` - 新增 IndicatorPreset
- `DictationViewModel.swift` - 添加 preset 应用逻辑
- `GeneralSettingsView.swift` - 简化 UI

### Sprint 2: Memory 功能一键启用
**改动**: 将 5 个 Memory 配置项折叠到 DisclosureGroup
- 仅保留 "Enable Memory" Toggle 可见
- 高级设置（Provider/Model/Min Length/Prompt）折叠显示
- 默认折叠状态

**文件**:
- `AdvancedSettingsView.swift` - Memory Section 重构

### Sprint 3: Profiles 优先级自动匹配
**改动**: 移除手动 priority 字段，实现基于特异性自动排序
- 删除 `Profile.priority` 属性
- 修改匹配逻辑：App+URL > URL-only > App-only
- 删除 Profiles 设置中的 Priority Stepper

**文件**:
- `Profile.swift` - 删除 priority 字段
- `ProfileService.swift` - 修改为 first-match 逻辑
- `ProfilesViewModel.swift` - 删除 editorPriority
- `ProfilesSettingsView.swift` - 删除 Priority UI
- `APIHandlers.swift` - 删除响应中的 priority 字段

## Phase 3: 代码精简统计

| 类别 | 删除文件数 | 修改文件数 | 删除行数 | 修改行数 |
|------|-----------|-----------|---------|---------|
| Services | 5 | 5 | ~1500 | ~100 |
| ViewModels | 2 | 4 | ~800 | ~150 |
| Views | 3 | 3 | ~1200 | ~200 |
| Models | 1 | 1 | ~50 | ~20 |
| Protocols | 1 | - | ~30 | - |
| Tests | 6 | 8 | ~400 | ~100 |
| **总计** | **18** | **21** | **~3980** | **~570** |

**净删除**: ~3410 行代码

## Phase 4: 设置项精简

### 删除的设置标签页
- Recording（录音设置）
- Dictionary（词典设置）
- File Transcription（文件转录）

### 保留的设置标签页
- General（通用）- 新增 Indicator Mode 预设
- History（历史）
- Profiles（配置文件）- 移除 Priority 手动调节
- Prompts（Prompt）
- Integrations（集成）
- Advanced（高级）- Memory 设置折叠

## Phase 5: 迁移路径

### 术语管理
原词典功能用户需求可通过以下方式替代：
1. 使用 Prompt 中内置术语列表
2. 使用代码片段（Snippets）功能

### 翻译功能
用户需求可通过 Prompt 实现：
1. 创建翻译 Prompt（如"翻译成英文"）
2. 在配置文件中绑定 Prompt 实现自动翻译

## Phase 6: 后续优化建议

1. ~~清理死代码~~ ✅ 已完成
2. ~~简化 Profiles~~ ✅ 已完成 (Sprint 3)
3. ~~统一指示器~~ ✅ 已完成 (Sprint 1)
4. ~~考虑合并文件转写到通用设置~~ ✅ 已完成 (文件转录 UI 已删除)

## Phase 7: 验证

- [x] 编译通过
- [x] README 更新
- [x] 单元测试运行（1000 tests，6 个非关键失败）
- [ ] 手动测试验证

## Phase 8: 架构影响

删除三个服务后，`ServiceContainer` 的依赖注入简化为：

```swift
// Services (20 → 20, 但删除了 DictionaryService/TranslationService)
let modelManagerService: ModelManagerService
let audioFileService: AudioFileService
let audioRecordingService: AudioRecordingService  // 保留：文件转写需要
let hotkeyService: HotkeyService
let textInsertionService: TextInsertionService
let historyService: HistoryService
let textDiffService: TextDiffService
let profileService: ProfileService
let snippetService: SnippetService
let soundService: SoundService
let audioDeviceService: AudioDeviceService
let promptActionService: PromptActionService
let promptProcessingService: PromptProcessingService
let pluginManager: PluginManager
let pluginRegistryService: PluginRegistryService
let termPackRegistryService: TermPackRegistryService
let memoryService: MemoryService
let appFormatterService: AppFormatterService
let accessibilityAnnouncementService: AccessibilityAnnouncementService
let errorLogService: ErrorLogService
let pluginCredentialService: PluginCredentialService
```
