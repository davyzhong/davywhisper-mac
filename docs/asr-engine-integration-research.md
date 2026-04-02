# ASR 引擎下载与集成方案调研

> 对比项目：Mouthpiece (Electron) vs MouthType (Swift)
> 日期：2026-04-02

---

## 一、项目概览

| 维度 | Mouthpiece | MouthType |
|------|-----------|-----------|
| 技术栈 | Electron + React | Swift (native macOS) |
| 本地引擎 | whisper.cpp + sherpa-onnx (Parakeet) | whisper.cpp + sensevoice.cpp + sherpa-onnx (Paraformer) |
| 云端引擎 | OpenAI / Groq / Deepgram / Mistral / Soniox / 阿里百炼 | 阿里百炼 (WebSocket 流式 + HTTP) |
| 引擎通信 | localhost HTTP/WS 子进程 | 子进程 stdout 解析 |
| WhisperKit | **不使用** (用 whisper.cpp) | **不使用** (用 whisper.cpp) |

---

## 二、模型下载机制

### Mouthpiece

- **Whisper 模型**：从 HuggingFace (`ggerganov/whisper.cpp`) 直接下载 `.bin` 文件
- **Parakeet 模型**：从 GitHub Releases 下载 `.tar.bz2` 并解压
- **下载基础设施**：`downloadUtils.js` — 支持断点续传、重试(3次指数退避)、超时检测(30s)、磁盘空间检查、取消信号
- **镜像支持**：**无**，URL 全部硬编码为 `huggingface.co`

```
Whisper:  https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-{size}.bin
Parakeet: https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/xxx.tar.bz2
```

### MouthType

- **Whisper 模型**：从 `hf-mirror.com`（中国镜像）下载 `.bin` 文件
- **SenseVoice 模型**：从 `hf-mirror.com` 下载 `.gguf` 文件
- **Paraformer 模型**：从 GitHub Releases 下载 `.tar.bz2`
- **下载实现**：`URLSession.shared.bytes(from:)` 流式写入，32KB chunk，进度回调
- **镜像支持**：**全部使用 hf-mirror.com**

```
Whisper:    https://hf-mirror.com/ggerganov/whisper.cpp/resolve/main/ggml-{size}.bin
SenseVoice: https://hf-mirror.com/lovemefan/sense-voice-gguf/resolve/main/sense-voice-small-q4_0.gguf
Paraformer: https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/xxx.tar.bz2
```

---

## 三、模型存储路径

### Mouthpiece

```
~/.cache/mouthpiece/
  ├── whisper-models/          # ggml-base.bin, ggml-small.bin, ...
  ├── parakeet-models/         # {model-name}/encoder.int8.onnx, decoder, joiner, tokens
  └── models/                  # GGUF 推理模型 (Qwen3, Mistral 等)
```

- 旧路径 `~/.cache/openwhispr/` 自动迁移到新路径
- 引擎二进制打包在 `Contents/Resources/bin/`（build time）

### MouthType

```
~/Library/Application Support/MouthType/Models/
  ├── whisper/                 # ggml-tiny.bin, ggml-base.bin, ...
  ├── sensevoice/              # sense-voice-small-q4_0.gguf
  └── paraformer/              # sherpa-onnx-paraformer-zh-int8.onnx
```

- **Bundle-first 解析**：先查 `Bundle.main.url(forResource:)`，再查用户目录
- 打包模型在 `Contents/Resources/whisper-models/` 和 `Contents/Resources/sensevoice-models/`

---

## 四、开箱体验（首次启动）

### Mouthpiece

- 有 Onboarding 流程（欢迎 → 权限 → 快捷键），**但不下载模型**
- 模型需用户在 Settings → Model Manager 手动下载
- 如果已配置模型，启动时预热服务端进程（消除冷启动延迟）

### MouthType

- 有 Onboarding 流程（欢迎 → 权限 → 引擎选择 → AI配置 → 完成）
- 提示"首次使用时自动下载"，但实际也需手动下载
- **预打包模型**：Whisper Small (465MB) + SenseVoice Small (174MB) 直接内置在 app bundle 中
- 构建脚本 `scripts/build-app.sh` 负责复制模型到 bundle
- 默认使用 `small` 模型，开箱即可用

---

## 五、引擎抽象架构

### Mouthpiece：Manager + IPC 模式

```
Frontend (React)
    │ IPC calls
    ▼
main.js (Electron main process)
    ├── WhisperManager → WhisperServerManager → child_process (HTTP localhost)
    ├── ParakeetManager → ParakeetServerManager → ParakeetWsServer (WebSocket localhost)
    └── ModelManager → LlamaServerManager (推理)
```

- 每个引擎独立 Manager + ServerManager
- 引擎以 localhost HTTP/WS 服务形式运行
- 共享下载基础设施 (`downloadUtils.js`)
- 模型注册表 (`modelRegistryData.json`) 是单一数据源

### MouthType：Provider Protocol 模式

```
ASRProvider (protocol)
  ├── WhisperProvider      (本地，子进程 stdout)
  ├── SenseVoiceProvider   (本地，子进程 stdout)
  ├── ParaformerProvider   (本地，子进程 stdout)
  └── BailianStreamingProvider (云端，WebSocket + HTTP)
```

- 协议定义 `transcribe(audioURL:)` / `startStreaming()` / `stopStreaming()`
- `HotkeyMonitor` 根据 `settings.asrProvider` 路由到对应 Provider
- 本地引擎全部用子进程模式（`Process`），代码有一定重复

---

## 六、预打包策略对比

| 维度 | Mouthpiece | MouthType |
|------|-----------|-----------|
| ASR 模型打包 | **不打包**，全部运行时下载 | **打包 2 个** (Whisper Small + SenseVoice Small) |
| 引擎二进制 | 打包在 `Resources/bin/` | 打包在 `Resources/` |
| 首次可用 | 否（需手动下载模型） | **是**（预打包模型开箱即用） |
| Bundle 体积 | 较小（无模型） | ~640MB+ (含模型) |
| 模型解析优先级 | 仅用户目录 | **Bundle 优先，用户目录次之** |

---

## 七、对 DavyWhisper 的启示

### 1. 模型下载：需要中国镜像

- MouthType 的做法更适合中国市场：所有 HF 下载走 `hf-mirror.com`
- DavyWhisper 已设置 `HF_ENDPOINT=hf-mirror.com`（`main.swift`），方向正确
- 但 WhisperKit 的 HubApi 是否尊重此环境变量需要验证

### 2. 开箱体验：预打包基础模型

- MouthType 预打包 Whisper Small (465MB) + SenseVoice (174MB)
- DavyWhisper 的 `installBundledModelIfNeeded()` 设计了预打包逻辑，但模型目录不存在
- **建议**：下载 `openai_whisper-base` 模型到 `Resources/WhisperKitBaseModel/`，构建时嵌入 bundle

### 3. 路径解析：Bundle-first

- MouthType 的 `Bundle.main.url(forResource:)` → 用户目录 fallback 是好模式
- DavyWhisper 的 WhisperKitPlugin 应同时检查：
  - Bundle 内路径（预打包）
  - HubApi 下载路径（`downloadBase/models/argmaxinc/whisperkit-coreml/<id>`）
  - 旧路径（迁移兼容）

### 4. 引擎选择：WhisperKit vs whisper.cpp

- Mouthpiece 和 MouthType 都使用 whisper.cpp（非 WhisperKit）
- whisper.cpp 优势：模型格式统一（ggml .bin）、二进制小、跨平台
- WhisperKit 优势：CoreML 加速、Apple 原生集成、Apple Silicon 优化
- DavyWhisper 选择 WhisperKit 合理，但需解决模型下载/预打包问题

### 5. 架构模式

- DavyWhisper 的 Plugin SDK 模式比两个参考项目都更解耦
- 但可以借鉴 MouthType 的 Bundle-first 模型解析和 Mouthpiece 的下载重试/断点续传机制
