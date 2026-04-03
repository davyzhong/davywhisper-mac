# DavyWhisper 最优中文引擎集成方案

> 基于 Mouthpiece、MouthType、sherpa-onnx 源码调研
> 日期：2026-04-02
> v2 — 改用 Paraformer 作为默认中文引擎

---

## 一、引擎选型结论

### 对比数据

| 引擎 | 中文 CER (AISHELL) | 模型体积 | 推理速度 (RTF) | 流式支持 | 标点恢复 | 许可证 |
|------|-------------------|---------|---------------|---------|---------|--------|
| **Paraformer (标准)** | **~1.95%** | **217MB** (int8) | **~0.04-0.08** | **原生流式** | **支持** (CT-Transformer) | MIT/FunASL |
| **Paraformer (小型)** | **~2-3%** | **79MB** (int8) | **~0.076** | **原生流式** | **支持** | MIT/FunASL |
| SenseVoice-Small | ~2.0-2.5% | 228MB (int8) | ~0.10 | 无（仅 VAD 模拟） | 不支持 | MIT/FunASL |
| WhisperKit large-v3 | ~5.6% | ~3GB CoreML | ~0.5-1.0 | 原生流式 | 不支持 | MIT |
| WhisperKit base | ~8-10% | ~74MB CoreML | ~0.5-1.0 | 原生流式 | 不支持 | MIT |
| FireRedASR 1.1B | ~3.18% | ~1.1GB | 中等 | 无 | 不支持 | Apache 2.0 |

### 选型：Paraformer via sherpa-onnx

**为什么 Paraformer 优于 SenseVoice：**

1. **中文准确率更高** — CER 1.95% vs 2.5%，Paraformer 是目前中文 ASR 的标杆
2. **原生流式支持** — Paraformer-streaming 提供真正的实时转写，SenseVoice 只能 VAD 模拟
3. **更快** — RTF 0.04 vs 0.10（快 2.5 倍）
4. **标点恢复** — 配合 CT-Transformer 标点模型（72MB），中文转写自动加标点，这是硬需求
5. **同样走 sherpa-onnx** — 相同的集成路径，Apache 2.0 运行时

**推荐模型组合：**

| 用途 | ASR 模型 | 标点模型 | 总体积 |
|------|---------|---------|--------|
| **预打包（开箱可用）** | `paraformer-zh-small` (79MB int8) | `punct-ct-transformer-zh-en` (72MB int8) | **151MB** |
| 高质量升级 | `paraformer-zh-2024` (217MB int8) | 同上 (72MB) | **289MB** |
| 流式实时 | `streaming-paraformer-bilingual` (226MB int8) | 同上 (72MB) | **298MB** |
| 三语（含粤语） | `paraformer-trilingual` (234MB int8) | 同上 (72MB) | **306MB** |

**保留 WhisperKit 作为第二引擎**：99+ 语言支持、翻译功能、英文场景。

---

## 二、技术架构

### 2.1 sherpa-onnx 集成方式

**方案：xcframework 静态库 + Swift 包装器**

```
sherpa-onnx.xcframework     ← 预编译静态库（arm64 + x86_64）
SherpaOnnx.swift             ← Swift API 包装（从 sherpa-onnx 仓库 swift-api-examples/ 复制）
ParaformerPlugin.swift       ← DavyWhisper TranscriptionEnginePlugin 实现
```

**为什么不选 SPM？** sherpa-onnx 目前不支持 SPM（Issue #3428 已开），必须用 xcframework。

**为什么不选子进程？** MouthType 用的子进程模式（spawn CLI binary）有以下问题：
- 额外进程开销
- 无法共享内存
- 进程管理复杂（超时、崩溃处理）
- 无法直接访问模型状态

xcframework 静态库直接编译进 app binary，无进程间通信开销。

### 2.2 插件架构

```
TranscriptionEnginePlugin (protocol)
  ├── ParaformerPlugin           ← 新增，默认中文引擎
  ├── WhisperKitPlugin           ← 已有，英文/多语言/翻译引擎
  └── DeepgramPlugin 等          ← 已有，云端引擎
```

ParaformerPlugin 实现 `TranscriptionEnginePlugin` 协议：
- `providerId`: `"paraformer"`
- `providerDisplayName`: `"Paraformer (中文优化)"`
- `isConfigured`: 模型文件存在即 true（无需 API key）
- `supportsStreaming`: `true`（使用 streaming-paraformer 模型时）
- `transcribe()`: 调用 `SherpaOnnxOfflineRecognizer.decode()` + 标点恢复

### 2.3 文件结构

```
DavyWhisper-mac/
├── Plugins/
│   ├── ParaformerPlugin/
│   │   ├── ParaformerPlugin.swift       ← 插件主文件
│   │   ├── SherpaOnnx.swift             ← sherpa-onnx Swift API（从官方仓库复制）
│   │   └── manifest_paraformer.json     ← 编译式插件 manifest
│   ├── WhisperKitPlugin/                ← 已有，保持不变
│   └── ...
├── Libraries/
│   └── sherpa-onnx.xcframework/         ← 预编译静态库
│       ├── macos-arm64_x86_64/
│       └── Info.plist
├── Resources/
│   └── ParaformerModel/                 ← 预打包模型（不提交 Git）
│       ├── model.int8.onnx              ← Paraformer int8 模型 (79MB)
│       ├── tokens.txt                   ← 词表文件
│       └── PunctuationModel/
│           └── model.int8.onnx          ← 标点恢复模型 (72MB)
└── scripts/
    ├── download-sherpa-onnx.sh          ← 下载 xcframework
    └── download-paraformer-model.sh     ← 下载模型文件
```

### 2.4 project.yml 变更

```yaml
targets:
  DavyWhisper:
    sources:
      # ... 已有 sources ...
      - path: Plugins/ParaformerPlugin       # 新增
        excludes:
          - "**/*.xcstrings"
    dependencies:
      # ... 已有 dependencies ...
      - framework: Libraries/sherpa-onnx.xcframework    # 新增
        embed: false    # 静态库，不需要 embed
```

---

## 三、ParaformerPlugin 核心实现设计

### 3.1 插件类结构

```swift
@objc(ParaformerPlugin)
final class ParaformerPlugin: NSObject, TranscriptionEnginePlugin, @unchecked Sendable {
    static let pluginId = "com.davywhisper.paraformer"
    static let pluginName = "Paraformer"

    var providerId: String { "paraformer" }
    var providerDisplayName: String { "Paraformer (中文优化)" }

    var isConfigured: Bool { offlineRecognizer != nil || onlineRecognizer != nil }
    var supportsStreaming: Bool { onlineRecognizer != nil }
    var supportsTranslation: Bool { false }

    private var offlineRecognizer: SherpaOnnxOfflineRecognizer?
    private var onlineRecognizer: SherpaOnnxRecognizer?
    private var punctuation: SherpaOnnxOfflinePunctuationWrapper?
    private var host: HostServices?
    private var loadedModelId: String?
    private var modelState: ParaformerModelState = .notLoaded

    var supportedLanguages: [String] { ["zh", "en", "yue"] }
}
```

### 3.2 模型路径解析（Bundle-first）

```swift
private func resolveModelDir() -> URL? {
    // 1. Bundle 内预打包模型（开箱可用）
    if let url = Bundle.main.url(forResource: "ParaformerModel", withExtension: nil),
       FileManager.default.fileExists(atPath: url.appendingPathComponent("model.int8.onnx").path) {
        return url
    }
    // 2. 插件数据目录（已安装/下载）
    if let dir = host?.pluginDataDirectory {
        let modelDir = dir.appendingPathComponent("models/paraformer")
        if FileManager.default.fileExists(atPath: modelDir.appendingPathComponent("model.int8.onnx").path) {
            return modelDir
        }
    }
    return nil
}

private func resolvePunctuationModelPath() -> String? {
    // 1. Bundle 内
    if let url = Bundle.main.url(forResource: "PunctuationModel", withExtension: nil,
                                   subdirectory: "ParaformerModel"),
       let file = url.appendingPathComponent("model.int8.onnx"),
       FileManager.default.fileExists(atPath: file.path) {
        return file.path
    }
    // 2. 插件数据目录
    if let dir = host?.pluginDataDirectory {
        let path = dir.appendingPathComponent("models/punctuation/model.int8.onnx").path
        if FileManager.default.fileExists(atPath: path) { return path }
    }
    return nil
}
```

### 3.3 初始化离线识别器 + 标点

```swift
private func initializeOfflineRecognizer(modelDir: URL) {
    // Paraformer 离线模型：单个合并的 ONNX 文件
    let paraformerConfig = sherpaOnnxOfflineParaformerModelConfig(
        model: modelDir.appendingPathComponent("model.int8.onnx").path
    )
    let modelConfig = sherpaOnnxOfflineModelConfig(
        tokens: modelDir.appendingPathComponent("tokens.txt").path,
        paraformer: paraformerConfig,
        numThreads: 4,
        provider: "cpu",
        debug: 0,
        modelType: "",  // 空=标准；"paraformer"=2023-09-14模型（支持时间戳）
        modelingUnit: "cjkchar"
    )
    let featConfig = sherpaOnnxFeatureConfig(sampleRate: 16000, featureDim: 80)
    var config = sherpaOnnxOfflineRecognizerConfig(
        featConfig: featConfig,
        modelConfig: modelConfig
    )
    offlineRecognizer = SherpaOnnxOfflineRecognizer(config: &config)

    // 初始化标点恢复模型
    if let puncPath = resolvePunctuationModelPath() {
        let puncModelConfig = sherpaOnnxOfflinePunctuationModelConfig(
            ctTransformer: puncPath,
            numThreads: 1,
            debug: 0,
            provider: "cpu"
        )
        var puncConfig = sherpaOnnxOfflinePunctuationConfig(model: puncModelConfig)
        punctuation = SherpaOnnxOfflinePunctuationWrapper(config: &puncConfig)
    }
}
```

### 3.4 初始化流式识别器（可选，用于实时转写）

```swift
private func initializeOnlineRecognizer(modelDir: URL) {
    // 流式模型：独立的 encoder + decoder ONNX 文件
    let paraformerConfig = sherpaOnnxOnlineParaformerModelConfig(
        encoder: modelDir.appendingPathComponent("encoder.int8.onnx").path,
        decoder: modelDir.appendingPathComponent("decoder.int8.onnx").path
    )
    let modelConfig = sherpaOnnxOnlineModelConfig(
        tokens: modelDir.appendingPathComponent("tokens.txt").path,
        paraformer: paraformerConfig,
        numThreads: 4,
        provider: "cpu",
        debug: 0,
        modelingUnit: "cjkchar"
    )
    let featConfig = sherpaOnnxFeatureConfig(sampleRate: 16000, featureDim: 80)
    var config = sherpaOnnxOnlineRecognizerConfig(
        featConfig: featConfig,
        modelConfig: modelConfig,
        enableEndpoint: true,
        rule1MinTrailingSilence: 2.4,
        rule2MinTrailingSilence: 1.2,
        rule3MinUtteranceLength: 30.0,
        decodingMethod: "greedy_search"
    )
    onlineRecognizer = SherpaOnnxRecognizer(config: &config)
}
```

### 3.5 转写接口

```swift
func transcribe(
    audio: AudioData,
    language: String?,
    translate: Bool,
    prompt: String?
) async throws -> PluginTranscriptionResult {
    guard let offlineRecognizer else {
        throw PluginTranscriptionError.notConfigured
    }

    // 1. ASR 识别
    let result = offlineRecognizer.decode(samples: audio.samples, sampleRate: 16000)

    // 2. 标点恢复
    let finalText: String
    if let punctuation {
        finalText = punctuation.addPunct(text: result.text)
    } else {
        finalText = result.text
    }

    // 3. 构建结果
    let segments = result.tokens.enumerated().map { (i, token) in
        let start = i < result.timestamps.count ? Double(result.timestamps[i]) : 0
        let end = (i + 1) < result.timestamps.count ? Double(result.timestamps[i + 1]) : start + 0.1
        return PluginTranscriptionSegment(text: token, start: start, end: end)
    }

    return PluginTranscriptionResult(
        text: finalText,
        detectedLanguage: "zh",  // Paraformer 以中文为主
        segments: segments
    )
}
```

### 3.6 流式转写接口

```swift
// Paraformer 支持真正的流式，逐 chunk 送入音频
func transcribeStreaming(
    audioStream: AsyncStream<AudioData>,
    language: String?,
    onPartialResult: @Sendable @escaping (String) -> Void
) async throws -> PluginTranscriptionResult {
    guard let onlineRecognizer else {
        throw PluginTranscriptionError.notConfigured
    }

    let stream = onlineRecognizer.createStream()
    var finalText = ""

    for await audioChunk in audioStream {
        stream.acceptWaveform(samples: audioChunk.samples, sampleRate: 16000)

        while onlineRecognizer.isReady(stream: stream) {
            onlineRecognizer.decode(stream: stream)
        }

        let partial = onlineRecognizer.getResult(stream: stream)
        onPartialResult(partial.text)

        // 端点检测（用户停顿）
        if onlineRecognizer.isEndpoint(stream: stream) {
            let endpointResult = onlineRecognizer.getResult(stream: stream)
            finalText += endpointResult.text
            onlineRecognizer.reset(stream: stream)
        }
    }

    // 处理剩余音频
    stream.inputFinished()
    while onlineRecognizer.isReady(stream: stream) {
        onlineRecognizer.decode(stream: stream)
    }
    let lastResult = onlineRecognizer.getResult(stream: stream)
    finalText += lastResult.text

    // 标点恢复
    if let punctuation {
        finalText = punctuation.addPunct(text: finalText)
    }

    return PluginTranscriptionResult(text: finalText, detectedLanguage: "zh", segments: [])
}
```

### 3.7 Settings View

```swift
// 简洁的设置界面
VStack(alignment: .leading, spacing: 12) {
    Text("Paraformer (中文优化)")
        .font(.headline)
    Text("阿里巴巴达摩院非自回归语音识别引擎，中文准确率业界领先")
        .font(.callout)
        .foregroundStyle(.secondary)

    // 模型状态
    HStack {
        Circle().fill(modelState == .ready ? .green : .orange).frame(width: 8, height: 8)
        Text(modelStateText)
    }

    // 模型选择（如果有多个下载的模型）
    Picker("模型", selection: $selectedModel) {
        Text("小型 (79MB) — 推荐").tag("small")
        Text("标准 (217MB) — 更准确").tag("standard")
        Text("流式 (226MB) — 实时转写").tag("streaming")
    }

    // 无需 API key
    Text("本地运行，无需 API 密钥")
        .font(.caption)
        .foregroundStyle(.green)
}
```

---

## 四、模型下载详情

### 4.1 所有可用模型及下载 URL

**离线模型（通过 hf-mirror.com）：**

| 模型 | hf-mirror URL | 文件 | 体积 |
|------|--------------|------|------|
| 小型 (推荐预打包) | `hf-mirror.com/csukuangfj/sherpa-onnx-paraformer-zh-small-2024-03-09` | `model.int8.onnx` + `tokens.txt` | **79MB** |
| 标准质量 | `hf-mirror.com/csukuangfj/sherpa-onnx-paraformer-zh-2024-03-09` | `model.int8.onnx` + `tokens.txt` | **217MB** |
| 含时间戳 | `hf-mirror.com/csukuangfj/sherpa-onnx-paraformer-zh-2023-09-14` | `model.int8.onnx` + `tokens.txt` | **232MB** |
| 三语(含粤语) | `hf-mirror.com/csukuangfj/sherpa-onnx-paraformer-trilingual-zh-cantonese-en` | `model.int8.onnx` + `tokens.txt` | **234MB** |

**流式模型：**

| 模型 | hf-mirror URL | 文件 | 体积 |
|------|--------------|------|------|
| 中英双语 | `hf-mirror.com/csukuangfj/sherpa-onnx-streaming-paraformer-bilingual-zh-en` | `encoder.int8.onnx` + `decoder.int8.onnx` + `tokens.txt` | **226MB** |
| 三语(含粤语) | `hf-mirror.com/csukuangfj/sherpa-onnx-streaming-paraformer-trilingual-zh-cantonese-en` | 同上 | **228MB** |

**标点模型：**

| 模型 | hf-mirror URL | 文件 | 体积 |
|------|--------------|------|------|
| 中文标点 | `hf-mirror.com/csukuangfj/sherpa-onnx-punct-ct-transformer-zh-en-vocab272727-2024-04-12-int8` | `model.int8.onnx` | **72MB** |

**备选下载源（GitHub Releases）：**
```
https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/sherpa-onnx-paraformer-zh-small-2024-03-09.tar.bz2
https://github.com/k2-fsa/sherpa-onnx/releases/download/punctuation-models/sherpa-onnx-punct-ct-transformer-zh-en-vocab272727-2024-04-12-int8.tar.bz2
```

### 4.2 下载脚本

```bash
# scripts/download-paraformer-model.sh
#!/bin/bash
set -euo pipefail

MODEL_DIR="Resources/ParaformerModel"
PUNC_DIR="Resources/ParaformerModel/PunctuationModel"

# --- Paraformer Small (int8, 79MB) ---
mkdir -p "$MODEL_DIR"
if [ ! -f "$MODEL_DIR/model.int8.onnx" ]; then
    echo "Downloading Paraformer Small model from hf-mirror.com..."
    BASE_URL="https://hf-mirror.com/csukuangfj/sherpa-onnx-paraformer-zh-small-2024-03-09/resolve/main"
    curl -L -o "$MODEL_DIR/model.int8.onnx" "$BASE_URL/model.int8.onnx"
    curl -L -o "$MODEL_DIR/tokens.txt" "$BASE_URL/tokens.txt"
    echo "Paraformer model downloaded."
else
    echo "Paraformer model already exists."
fi

# --- Punctuation CT-Transformer (int8, 72MB) ---
mkdir -p "$PUNC_DIR"
if [ ! -f "$PUNC_DIR/model.int8.onnx" ]; then
    echo "Downloading Punctuation model from hf-mirror.com..."
    PUNC_URL="https://hf-mirror.com/csukuangfj/sherpa-onnx-punct-ct-transformer-zh-en-vocab272727-2024-04-12-int8/resolve/main"
    curl -L -o "$PUNC_DIR/model.int8.onnx" "$PUNC_URL/model.int8.onnx"
    echo "Punctuation model downloaded."
else
    echo "Punctuation model already exists."
fi

echo "Total model size:"
du -sh "$MODEL_DIR"
```

---

## 五、构建与打包流程

### 5.1 sherpa-onnx xcframework 获取

```bash
# scripts/download-sherpa-onnx.sh
#!/bin/bash
set -euo pipefail

if [ -d "Libraries/sherpa-onnx.xcframework" ]; then
    echo "sherpa-onnx xcframework already exists."
    exit 0
fi

mkdir -p Libraries

# 方案 A：从源码构建（推荐，可控）
git clone --depth 1 https://github.com/k2-fsa/sherpa-onnx.git /tmp/sherpa-onnx
cd /tmp/sherpa-onnx
./build-swift-macos.sh
cp -r sherpa-onnx.xcframework "$OLDPWD/Libraries/"
cd "$OLDPWD"
rm -rf /tmp/sherpa-onnx

# 方案 B：从 GitHub Releases 下载预编译
# VERSION="1.10.30"
# curl -L "https://github.com/k2-fsa/sherpa-onnx/releases/download/v${VERSION}/sherpa-onnx-xcframework-v${VERSION}.tar.bz2" | tar xj -C Libraries/

echo "sherpa-onnx xcframework ready."
```

### 5.2 .gitignore 更新

```
# 预打包模型和库（通过脚本下载，不提交 Git）
Libraries/sherpa-onnx.xcframework/
Resources/ParaformerModel/
```

### 5.3 完整构建流程

```bash
# 1. 下载依赖（首次或 CI）
./scripts/download-sherpa-onnx.sh
./scripts/download-paraformer-model.sh

# 2. 生成 Xcode 项目
xcodegen generate

# 3. 构建
xcodebuild -project DavyWhisper.xcodeproj -scheme DavyWhisper \
  -configuration Debug -destination 'platform=macOS,arch=arm64' \
  CODE_SIGN_IDENTITY='-' CODE_SIGNING_REQUIRED=NO

# 4. 验证
ls -la build/Debug/DavyWhisper.app/Contents/Resources/ParaformerModel/
```

---

## 六、默认引擎策略

### 6.1 首次启动逻辑

```
首次启动 → 检查 Paraformer 模型
  ├── 存在 → 设为默认引擎（中文最优）
  │         自动加载离线识别器 + 标点模型
  └── 不存在 → 检查 WhisperKit 模型
        ├── 存在 → 设为默认引擎（英文通用）
        └── 不存在 → 提示用户下载模型
```

### 6.2 引擎推荐逻辑

```swift
// 根据用户语言偏好推荐引擎
if preferredLanguage.hasPrefix("zh") {
    recommendEngine = "paraformer"   // 中文 → Paraformer
} else {
    recommendEngine = "whisper"      // 其他语言 → WhisperKit
}
```

---

## 七、风险与缓解

| 风险 | 影响 | 缓解措施 |
|------|------|----------|
| FunASL 模型许可证 | 商用需审查 | 确认 FunASL MODEL_LICENSE；如受限则改为用户自行下载模式 |
| sherpa-onnx xcframework 体积 (~50-80MB) | 增加 app 体积 | 可接受，静态库只增加二进制体积 |
| 模型体积 151MB (ASR+标点) | 增加 app bundle | MouthType 预打包 640MB 验证可行；预打包用小型模型(79MB) |
| sherpa-onnx 无 SPM 支持 | 集成复杂度 | xcframework 已成熟；SPM 在 Issue #3428 追踪 |
| Paraformer 小型模型准确率略低于标准版 | 中文准确率 | 用户可从 Settings 下载标准版(217MB) |
| xcframework 双架构 | 构建复杂 | sherpa-onnx 官方脚本已支持 universal binary |

### 7.1 许可证详情

- **sherpa-onnx 运行时**：Apache 2.0 — 明确可商用
- **Paraformer 模型权重**：[FunASL MODEL_LICENSE](https://github.com/modelscope/FunASR/blob/main/MODEL_LICENSE)
  - 允许非商业和学术使用
  - **商用需联系阿里获取授权**（或查看最新许可证更新）
- **备选方案**：如果许可证受限，改为运行时下载模式（用户自行承担许可责任）

---

## 八、实施路线图

### Phase 0：准备工作（1天）

- [ ] 下载 sherpa-onnx xcframework，验证 macOS 编译
- [ ] 下载 Paraformer small int8 模型 + 标点模型
- [ ] 编写测试代码验证 sherpa-onnx Swift API 可以加载模型并推理
- [ ] 审查 FunASL MODEL_LICENSE，确认商用合规
- [ ] 创建目录结构和下载脚本

### Phase 1：最小可用（2-3天）

- [ ] 将 `sherpa-onnx.xcframework` 加入项目
- [ ] 复制 `SherpaOnnx.swift` 包装器到 `Plugins/ParaformerPlugin/`
- [ ] 实现 `ParaformerPlugin`（`TranscriptionEnginePlugin` 协议）
- [ ] 创建 `manifest_paraformer.json`
- [ ] 更新 `project.yml` 添加源文件和 framework 依赖
- [ ] 预打包模型到 bundle
- [ ] 更新 `PluginManager.loadCompiledPlugins()` 添加 "ParaformerPlugin"
- [ ] 构建验证 + 基本转写测试

### Phase 2：体验优化（1-2天）

- [ ] Bundle-first 模型解析
- [ ] 默认引擎推荐逻辑（中文 → Paraformer）
- [ ] Settings View（模型选择、状态显示、下载升级）
- [ ] 标点恢复集成
- [ ] 镜像下载逻辑（hf-mirror.com 默认）

### Phase 3：流式 + 高级功能（可选）

- [ ] 流式 Paraformer 模型下载和集成
- [ ] 流式转写 UI（实时显示部分结果）
- [ ] 标准质量模型下载升级选项
- [ ] 三语模型（粤语支持）
- [ ] VAD 集成（语音活动检测，优化录音体验）

---

## 九、与现有代码的兼容性

### 不需要修改的文件

- `WhisperKitPlugin.swift` — 保持不变，作为第二引擎
- `ModelManagerService.swift` — 已支持多引擎路由
- `AudioRecordingService.swift` — 已通过 `TranscriptionEnginePlugin` 协议抽象
- 所有云端插件（Deepgram, OpenAI 等）— 不受影响

### 需要新增的文件

| 文件 | 说明 |
|------|------|
| `Plugins/ParaformerPlugin/ParaformerPlugin.swift` | 插件主文件 |
| `Plugins/ParaformerPlugin/SherpaOnnx.swift` | sherpa-onnx Swift API（从官方仓库 `swift-api-examples/` 复制） |
| `Plugins/ParaformerPlugin/manifest_paraformer.json` | 插件清单 |
| `Libraries/sherpa-onnx.xcframework/` | 预编译静态库 |
| `Resources/ParaformerModel/model.int8.onnx` | Paraformer int8 模型 (79MB) |
| `Resources/ParaformerModel/tokens.txt` | 词表文件 |
| `Resources/ParaformerModel/PunctuationModel/model.int8.onnx` | 标点恢复模型 (72MB) |
| `scripts/download-sherpa-onnx.sh` | 下载 xcframework |
| `scripts/download-paraformer-model.sh` | 下载模型 |

### 需要修改的文件

| 文件 | 修改内容 |
|------|----------|
| `project.yml` | 添加 ParaformerPlugin sources + sherpa-onnx framework dependency |
| `DavyWhisper/Services/PluginManager.swift` | `pluginNames` 数组添加 "ParaformerPlugin" |

---

## 十、量化目标

| 指标 | 当前 (WhisperKit base) | 目标 (Paraformer small) | 提升 |
|------|----------------------|------------------------|------|
| 中文 CER | ~8-10% | **~2-3%** | **3-4x** |
| 推理速度 (RTF) | ~0.5-1.0 | **~0.076** | **7-13x** |
| 首次启动可用 | 否（需下载模型） | **是**（预打包 151MB） | 0 → 1 |
| 标点恢复 | 无 | **有**（CT-Transformer） | 0 → 1 |
| 流式转写 | WhisperKit 支持 | **原生流式**（升级后） | 对齐 |
| 模型体积 | 74MB (base) | 151MB (ASR+标点) | +77MB |
| 支持语言 | 99+ | 中/英（粤语可选） | - |

---

## 附录：Paraformer 模型选择决策树

```
用户首次启动
  └── 预打包 Paraformer Small (79MB) + 标点 (72MB) = 151MB
      ├── 中文场景够用？→ 保持
      └── 需要更高质量？
          ├── 下载 Paraformer 标准 (217MB) → 替换 small
          ├── 需要实时转写？→ 下载流式模型 (226MB)
          └── 需要粤语？→ 下载三语模型 (234MB)
```
