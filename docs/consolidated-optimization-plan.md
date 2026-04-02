# DavyWhisper 整改优化方案

> 基于 asr-engine-integration-research.md、paraformer-integration-plan.md、simplification-plan.md 综合整合
> 日期：2026-04-02
> 状态：已规划，待 review

---

## 一、整改目标

| 维度 | 当前 | 目标 |
|------|------|------|
| 中文 ASR 准确率 | ~8-10% CER (WhisperKit base) | **~2-3% CER** (Paraformer) |
| 开箱可用性 | 否（需下载模型） | **是**（预打包模型） |
| 中国网络适配 | 部分 | **全面**（hf-mirror + ghproxy） |

---

## 二、Phase 1：中文引擎集成（核心）

### 2.1 引擎选型

**默认中文引擎：Paraformer via sherpa-onnx**

| 指标 | WhisperKit base（当前） | Paraformer small（目标） |
|------|----------------------|------------------------|
| 中文 CER | ~8-10% | **~2-3%** |
| 推理速度 RTF | ~0.5-1.0 | **~0.076** |
| 标点恢复 | 无 | **CT-Transformer (72MB)** |
| 流式支持 | 有 | **有（streaming模型）** |
| 模型体积 | 74MB | 79MB |

**保留 WhisperKit**：英文场景、翻译功能、多语言兜底。

### 2.2 预打包模型策略

参考 MouthType 的 Bundle-first 模式：

```
Resources/
├── WhisperKitBaseModel/          ← WhisperKit base 模型（当前目录不存在，需下载）
│   └── openai_whisper-base/     ← CoreML 文件
└── ParaformerModel/              ← 新增
    ├── model.int8.onnx          ← Paraformer small (79MB)
    ├── tokens.txt                ← 词表
    └── PunctuationModel/
        └── model.int8.onnx      ← CT-Transformer 标点 (72MB)
```

总预打包体积：**151MB**

### 2.3 下载脚本

```bash
# scripts/download-models.sh（新增）

MODEL_DIR="Resources"
HF_BASE="https://hf-mirror.com/csukuangfj"

# 1. Paraformer small (79MB)
mkdir -p "$MODEL_DIR/ParaformerModel"
curl -L "$HF_BASE/sherpa-onnx-paraformer-zh-small-2024-03-09/resolve/main/model.int8.onnx" \
    -o "$MODEL_DIR/ParaformerModel/model.int8.onnx"
curl -L "$HF_BASE/sherpa-onnx-paraformer-zh-small-2024-03-09/resolve/main/tokens.txt" \
    -o "$MODEL_DIR/ParaformerModel/tokens.txt"

# 2. 标点模型 (72MB)
mkdir -p "$MODEL_DIR/ParaformerModel/PunctuationModel"
curl -L "$HF_BASE/sherpa-onnx-punct-ct-transformer-zh-en-vocab272727-2024-04-12-int8/resolve/main/model.int8.onnx" \
    -o "$MODEL_DIR/ParaformerModel/PunctuationModel/model.int8.onnx"
```

### 2.4 sherpa-onnx xcframework 获取

```bash
# scripts/download-sherpa-onnx.sh（新增）
VERSION="1.10.30"

# 方案A：从 GitHub Releases 下载（推荐）
curl -L "https://mirror.ghproxy.com/https://github.com/k2-fsa/sherpa-onnx/releases/download/v${VERSION}/sherpa-onnx-xcframework-v${VERSION}.tar.bz2" \
    | tar xj -C Libraries/

# 方案B：从源码构建
git clone --depth 1 https://github.com/k2-fsa/sherpa-onnx.git /tmp/sherpa-onnx
cd /tmp/sherpa-onnx && ./build-swift-macos.sh
cp -r sherpa-onnx.xcframework "$OLDPWD/Libraries/"
```

### 2.5 新增文件清单

| 文件 | 说明 |
|------|------|
| `Plugins/ParaformerPlugin/ParaformerPlugin.swift` | TranscriptionEnginePlugin 实现 |
| `Plugins/ParaformerPlugin/SherpaOnnx.swift` | 从 sherpa-onnx/swift-api-examples/ 复制 |
| `Plugins/ParaformerPlugin/manifest_paraformer.json` | 插件清单 |
| `Libraries/sherpa-onnx.xcframework/` | 预编译静态库 |
| `Resources/ParaformerModel/` | 预打包模型 |
| `scripts/download-models.sh` | 下载所有模型 |
| `scripts/download-sherpa-onnx.sh` | 下载 xcframework |

### 2.6 修改文件清单

| 文件 | 修改内容 |
|------|---------|
| `project.yml` | 添加 ParaformerPlugin sources + sherpa-onnx framework dependency |
| `DavyWhisper/Services/PluginManager.swift` | pluginNames 添加 "ParaformerPlugin" |

---

## 三、Phase 2：模型路径修复（收尾）

### 3.1 WhisperKit 预打包目录修复

`WhisperKitPlugin.swift` 的 `installBundledModelIfNeeded()` 设计正确，但 `Resources/WhisperKitBaseModel/` 目录不存在，函数静默跳过。

**修复方式：**
- 运行 `scripts/download-whisperkit-model.sh` 下载 base 模型到 `Resources/WhisperKitBaseModel/`
- 或完全移除 WhisperKit 预打包逻辑，依赖 HubApi 下载

### 3.2 镜像环境变量验证

当前 `main.swift` 设置 `HF_ENDPOINT=hf-mirror.com`，需验证 WhisperKit 0.9.0 的 `HubApi` 是否正确使用此环境变量。

---

## 四、执行顺序

```
Phase 1（核心价值）
  ├── 1.1 下载 sherpa-onnx xcframework
  ├── 1.2 下载 Paraformer + 标点模型
  ├── 1.3 实现 ParaformerPlugin
  ├── 1.4 更新 project.yml + PluginManager
  └── 1.5 构建验证 + 功能测试
        ↓
Phase 2（收尾）
  ├── 2.1 修复 WhisperKit 预打包目录
  └── 2.2 验证镜像环境变量
```

---

## 五、预估工作量

| 任务 | 工作量 |
|------|--------|
| sherpa-onnx xcframework 获取 + 验证 | 1-2h |
| Paraformer + 标点模型下载 | 0.5h |
| ParaformerPlugin 实现（离线+标点） | 4-6h |
| project.yml + PluginManager 修改 | 0.5h |
| 构建 + 功能测试 | 2h |
| WhisperKit 预打包修复 + 镜像验证 | 0.5h |

**总计：约 8-11 小时**

---

## 六、风险与备选

| 风险 | 影响 | 备选方案 |
|------|------|---------|
| FunASL 模型许可证商用限制 | 商业用户可能受限 | 改为用户自行下载模式（参考 MouthType） |
| sherpa-onnx xcframework 下载失败 | 阻塞 Phase 1 | 使用镜像或从源码构建 |
| ParaformerPlugin 影响现有录音流程 | 需回归测试 | 并行开发，不修改现有 WhisperKit 路径 |
