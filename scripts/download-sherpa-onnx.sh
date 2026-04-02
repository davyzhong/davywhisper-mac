#!/bin/bash
# Download sherpa-onnx static library and Paraformer ASR models
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

SHERPA_ONNX_VERSION="1.12.34"
ORT_VERSION="1.23.2"

LIBRARIES_DIR="$PROJECT_DIR/Libraries"
MODEL_DIR="$PROJECT_DIR/DavyWhisper/Resources/ParaformerModel"

echo "==> Downloading sherpa-onnx xcframework v${SHERPA_ONNX_VERSION}..."
mkdir -p "$LIBRARIES_DIR"
curl -sL "https://github.com/k2-fsa/sherpa-onnx/releases/download/v${SHERPA_ONNX_VERSION}/sherpa-onnx-v${SHERPA_ONNX_VERSION}-macos-xcframework-static.tar.bz2" \
  | tar xjf - -C "$LIBRARIES_DIR" --strip-components=1 "sherpa-onnx-v${SHERPA_ONNX_VERSION}-macos-xcframework-static/sherpa-onnx.xcframework"

# Create modulemap for Swift interop
MODULEMAP_DIR="$LIBRARIES_DIR/sherpa-onnx.xcframework/macos-arm64_x86_64/Headers"
cat > "$MODULEMAP_DIR/module.modulemap" << 'MMAP'
module CSherpaOnnx {
    header "sherpa-onnx/c-api/c-api.h"
    link "sherpa-onnx"
    export *
}
MMAP

echo "==> Downloading onnxruntime static library v${ORT_VERSION}..."
curl -sL "https://github.com/csukuangfj/onnxruntime-libs/releases/download/v${ORT_VERSION}/onnxruntime-osx-universal2-static_lib-${ORT_VERSION}.zip" \
  -o /tmp/onnxruntime-static.zip
unzip -o /tmp/onnxruntime-static.zip "*/lib/libonnxruntime.a" -d /tmp
cp /tmp/onnxruntime-osx-universal2-static_lib-${ORT_VERSION}/lib/libonnxruntime.a "$LIBRARIES_DIR/libonnxruntime.a"
rm -f /tmp/onnxruntime-static.zip

echo "==> Downloading Paraformer ASR model..."
mkdir -p "$MODEL_DIR"
MODEL_URL="https://hf-mirror.com/csukuangfj/sherpa-onnx-paraformer-zh-small-2024-03-09/resolve/main"
curl -sL "${MODEL_URL}/model.int8.onnx" -o "$MODEL_DIR/model.int8.onnx"
curl -sL "${MODEL_URL}/tokens.txt" -o "$MODEL_DIR/tokens.txt"

echo "==> Downloading Punctuation model..."
PUNC_DIR="$MODEL_DIR/PunctuationModel"
mkdir -p "$PUNC_DIR"
curl -sL "https://github.com/k2-fsa/sherpa-onnx/releases/download/punctuation-models/sherpa-onnx-punct-ct-transformer-zh-en-vocab272727-2024-04-12-int8.tar.bz2" \
  | tar xjf - -C "$PUNC_DIR" --strip-components=1 "sherpa-onnx-punct-ct-transformer-zh-en-vocab272727-2024-04-12-int8/model.int8.onnx"
curl -sL "https://github.com/k2-fsa/sherpa-onnx/releases/download/punctuation-models/sherpa-onnx-punct-ct-transformer-zh-en-vocab272727-2024-04-12-int8.tar.bz2" \
  | tar xjf - -C "$PUNC_DIR" --strip-components=1 "sherpa-onnx-punct-ct-transformer-zh-en-vocab272727-2024-04-12-int8/tokens.json"

echo "==> Verifying downloads..."
file="$LIBRARIES_DIR/libonnxruntime.a" && test -f "$file" && echo "  ✅ $(basename $file) ($(du -h "$file" | cut -f1))"
file="$LIBRARIES_DIR/sherpa-onnx.xcframework/macos-arm64_x86_64/libsherpa-onnx.a" && test -f "$file" && echo "  ✅ $(basename $file) ($(du -h "$file" | cut -f1))"
file="$MODEL_DIR/model.int8.onnx" && test -f "$file" && echo "  ✅ Paraformer model ($(du -h "$file" | cut -f1))"
file="$MODEL_DIR/PunctuationModel/model.int8.onnx" && test -f "$file" && echo "  ✅ Punctuation model ($(du -h "$file" | cut -f1))"

echo "==> Done! Run 'xcodegen generate' to update the Xcode project."
