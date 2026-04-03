# DavyWhisper 模型下载与集成改进计划

> 基于 Mouthpiece (Electron) 和 MouthType (Swift) 项目的调研成果
> 日期：2026-04-02

---

## 一、现状问题

| 问题 | 根因 | 影响 |
|------|------|------|
| 首次启动无可用引擎 | WhisperKit base 模型未预打包，`installBundledModelIfNeeded()` 因目录不存在而静默跳过 | 用户看到"所有引擎报错" |
| 镜像下载不可靠 | WhisperKit 的 `HubApi` 可能不尊重 `HF_ENDPOINT` 环境变量 | 中国用户下载失败 |
| 无下载重试机制 | `WhisperKit.download()` 失败后直接抛错，无重试/断点续传 | 网络波动导致彻底失败 |
| 模型路径逻辑复杂 | bundled + hubApi + 旧路径 三套路径共存，易出错 | 已修复但脆弱 |

---

## 二、借鉴方案（分阶段）

### Phase 1：预打包基础模型 — 开箱可用

**借鉴来源：MouthType**
- MouthType 预打包 Whisper Small (465MB) + SenseVoice Small (174MB)
- 构建脚本 `scripts/build-app.sh` 复制模型到 app bundle
- `AppSettings` 用 Bundle-first 解析：`Bundle.main.url(forResource:)` → 用户目录 fallback

**实施方案：**

#### 1.1 下载 WhisperKit base 模型

WhisperKit 使用 CoreML 格式（非 ggml .bin），需通过 WhisperKit 下载一次后打包：

```bash
# 创建临时 Swift 脚本，调用 WhisperKit.download() 下载 base 模型
# 下载后的文件结构：
#   openai_whisper-base/
#     ├── audio_encoder.mlmodelc/
#     ├── decoder.mlmodelc/
#     ├── encoder.mlmodelc/
#     └── tokenizer.json / vocabulary.json 等
```

目标路径：`Resources/WhisperKitBaseModel/openai_whisper-base/`

#### 1.2 修改 project.yml 将模型打入 bundle

```yaml
# 在 DavyWhisper target 的 sources 中添加：
- path: Resources/WhisperKitBaseModel
  buildPhase: resources
```

或通过 `scripts/build-release-local.sh` 构建后复制（参考 MouthType）。

#### 1.3 installBundledModelIfNeeded() 已就绪

当前代码（`WhisperKitPlugin.swift:342-365`）已经实现了：
- 检查 `Bundle.main.resourceURL/WhisperKitBaseModel/openai_whisper-base/`
- 复制到 `downloadBase/openai_whisper-base/`
- 设为默认选中模型

**只需确保模型文件存在，此逻辑即可生效。**

#### 1.4 Bundle-first 解析增强

借鉴 MouthType 的模式，在 `loadModel()` 中增加 Bundle 内路径检查：

```
查找顺序：
1. Bundle.main (预打包) → Resources/WhisperKitBaseModel/<variant>/
2. 用户目录 (已安装) → downloadBase/<variant>/
3. HubApi 下载目录 → downloadBase/models/argmaxinc/whisperkit-coreml/<variant>/
4. 在线下载 → WhisperKit.download(endpoint: hf-mirror.com)
```

---

### Phase 2：镜像下载加固

**借鉴来源：MouthType**
- MouthType 全部硬编码 `hf-mirror.com`
- WhisperKit 的 `HubApi` 需要显式传 `endpoint` 参数

**实施方案：**

#### 2.1 确认 WhisperKit.download() 的 endpoint 参数生效

当前代码已传入 `endpoint` 参数（`WhisperKitPlugin.swift:201-206`）：
```swift
let hfEndpoint = ProcessInfo.processInfo.environment["HF_ENDPOINT"] ?? "https://huggingface.co"
modelFolder = try await WhisperKit.download(
    variant: modelDef.id,
    downloadBase: downloadBase,
    endpoint: hfEndpoint
)
```

需验证：WhisperKit 0.9.0 的 `download(endpoint:)` 是否正确传递给 `HubApi`。

#### 2.2 硬编码 mirror URL 作为默认值

```swift
// 改为硬编码默认值，不依赖环境变量
let hfEndpoint = UserDefaults.standard.bool(forKey: "useOriginalHF") == true
    ? "https://huggingface.co"
    : "https://hf-mirror.com"
```

这样即使 `main.swift` 的 `setenv` 未生效也能使用镜像。

#### 2.3 下载失败自动切换镜像

```swift
// 伪代码
do {
    modelFolder = try await download(via: mirrorEndpoint)
} catch {
    // 镜像失败，尝试原始地址
    modelFolder = try await download(via: "https://huggingface.co")
}
```

---

### Phase 3：下载体验优化

**借鉴来源：Mouthpiece**
- `downloadUtils.js`：3 次指数退避重试、断点续传（Range header）、30s 超时检测、磁盘空间检查
- 进度回调 + 取消信号

**实施方案：**

#### 3.1 WhisperKit 下载重试包装

```swift
func downloadWithRetry(variant: String, maxRetries: Int = 3) async throws -> URL {
    var lastError: Error?
    for attempt in 0..<maxRetries {
        do {
            return try await WhisperKit.download(variant: variant, ...)
        } catch {
            lastError = error
            wkLogger.warning("Download attempt \(attempt+1) failed: \(error)")
            try? await Task.sleep(for: .seconds(pow(2.0, Double(attempt))))
        }
    }
    throw lastError!
}
```

#### 3.2 磁盘空间预检查

```swift
func checkDiskSpace(requiredMB: Int) -> Bool {
    let systemAttributes = try? FileManager.default.attributesOfFileSystem(forPath: downloadBase.path)
    let freeSpace = systemAttributes?[.systemFreeSize] as? UInt64 ?? 0
    return freeSpace > UInt64(requiredMB) * 1024 * 1024
}
```

#### 3.3 下载前显示模型大小警告

在 Settings UI 的 "Download & Load" 按钮旁显示预估大小和网络要求。

---

### Phase 4：多引擎预打包（长期）

**借鉴来源：MouthType 的多引擎预打包**
- Whisper Small + SenseVoice Small 均预打包
- 用户可按需下载更大模型

**未来可考虑：**
- 预打包 SenseVoice 或 Paraformer 作为中文专用引擎
- 模型按语言推荐（中文 → SenseVoice/Paraformer，英文 → WhisperKit）
- 构建脚本自动化模型下载和打包

---

## 三、优先级排序

| 优先级 | 任务 | 工作量 | 影响 |
|--------|------|--------|------|
| **P0** | 下载 WhisperKit base 模型并放入 Resources/ | 1-2h | 开箱即可用 |
| **P0** | 验证 project.yml 模型资源打包配置 | 0.5h | 构建能包含模型 |
| **P1** | 硬编码 mirror URL，不依赖环境变量 | 0.5h | 中国用户可靠下载 |
| **P1** | 下载重试 + 自动切换镜像 | 1h | 网络波动容错 |
| **P2** | 磁盘空间预检查 | 0.5h | 用户体验 |
| **P3** | 多引擎预打包（SenseVoice/Paraformer） | 2-3天 | 中文体验提升 |

---

## 四、实施步骤（P0 详细）

### Step 1：下载 WhisperKit base 模型

```bash
# 方案 A：用 Swift 脚本调用 WhisperKit SDK 下载
cat > /tmp/download_whisper_base.swift << 'EOF'
import Foundation
import WhisperKit

let downloadBase = FileManager.default.currentDirectoryPath + "/Resources/WhisperKitBaseModel"
try FileManager.default.createDirectory(atPath: downloadBase, withIntermediateDirectories: true)

let url = try await WhisperKit.download(
    variant: "openai_whisper-base",
    downloadBase: URL(fileURLWithPath: downloadBase),
    endpoint: "https://hf-mirror.com"
)
print("Downloaded to: \(url.path)")
EOF

# 方案 B：手动从 hf-mirror.com 下载 CoreML 模型文件
# URL: https://hf-mirror.com/argmaxinc/whisperkit-coreml/resolve/main/openai_whisper-base/
```

### Step 2：放入项目 Resources 目录

```
Resources/
  └── WhisperKitBaseModel/
      └── openai_whisper-base/     ← CoreML 模型文件
          ├── audio_encoder.mlmodelc/
          ├── decoder.mlmodelc/
          ├── encoder.mlmodelc/
          ├── tokenizer.json
          └── ...
```

### Step 3：更新 project.yml

确保 `Resources/WhisperKitBaseModel` 被 XcodeGen 包含为资源。

### Step 4：构建验证

```bash
xcodegen generate
xcodebuild build -project DavyWhisper.xcodeproj -scheme DavyWhisper \
  -configuration Debug -destination 'platform=macOS,arch=arm64' \
  CODE_SIGN_IDENTITY='-' CODE_SIGNING_REQUIRED=NO

# 验证模型在 bundle 中
ls build/Debug/DavyWhisper.app/Contents/Resources/WhisperKitBaseModel/
```

### Step 5：运行验证

启动 app，确认：
1. WhisperKit 引擎自动加载 base 模型
2. 录音转写正常工作
3. Settings 中显示 base 模型为已加载状态

---

## 五、风险评估

| 风险 | 缓解措施 |
|------|----------|
| base 模型体积 (~74MB) 增加 app 体积 | 可接受，MouthType 预打包 640MB+ |
| CoreML 模型格式兼容性 | 使用 WhisperKit 0.9.0 的标准下载 |
| Git LFS 需求（模型是大文件） | 将模型放在构建服务器下载，不提交到 Git |
| hf-mirror.com 不可用 | P1 的镜像切换逻辑兜底 |

---

## 六、不提交模型到 Git 的方案

模型文件应通过构建脚本下载，而非提交到 Git：

```bash
# scripts/download-base-model.sh
#!/bin/bash
set -euo pipefail

MODEL_DIR="Resources/WhisperKitBaseModel/openai_whisper-base"
if [ -d "$MODEL_DIR" ]; then
    echo "Base model already exists, skipping download."
    exit 0
fi

echo "Downloading WhisperKit base model from hf-mirror.com..."
mkdir -p "$MODEL_DIR"

# 下载 CoreML 模型文件
BASE_URL="https://hf-mirror.com/argmaxinc/whisperkit-coreml/resolve/main/openai_whisper-base"

for file in tokenizer.json vocabulary.json; do
    curl -L -o "$MODEL_DIR/$file" "$BASE_URL/$file"
done

# 下载 mlmodelc 目录（需 huggingface_hub 或手动下载）
# 实际操作中可能需要 Python 脚本或 Swift 工具
```

在 `xcodegen generate` 或 `build-release-local.sh` 前调用此脚本。
