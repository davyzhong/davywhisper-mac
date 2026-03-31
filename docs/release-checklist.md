# 发布检查清单

## RC 之前

- `xcodebuild test -project DavyWhisper.xcodeproj -scheme DavyWhisper -destination 'platform=macOS,arch=arm64' -parallel-testing-enabled NO CODE_SIGN_IDENTITY='-' CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO`
- `swift test --package-path DavyWhisperPluginSDK`
- `xcodebuild -project DavyWhisper.xcodeproj -scheme DavyWhisper -configuration Release -derivedDataPath build -destination 'generic/platform=macOS' CODE_SIGN_IDENTITY='-' CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO`
- `bash scripts/check_first_party_warnings.sh build.log`
- 审查 README、安全策略和支持矩阵

## RC 冒烟检查

- 在 `release-candidate` 通道发布 `1.1.0-rc*`，在 `daily` 通道发布每日构建
- 稳定构建必须仅使用默认通道
- 全新安装
- 权限恢复
- 第一次语音输入
- 文件转写
- Prompt Action
- Prompt 向导步骤（跨标签导航）
- Prompt 拖放重排序
- 历史编辑/导出
- 历史和指示器中的后处理透明度
- 配置文件匹配
- 插件启用/禁用
- 社区术语包下载和应用
- App 音频录制（带独立音轨）
- Google Cloud Speech-to-Text 插件
- 声音反馈设置（启用/禁用/更改声音）
- 非阻塞模型下载
- 词典 JSON 导出和导入
- Parakeet V2/V3 模型版本选择
- 本地验证 CLI 和 HTTP API
- 从 `1.0.0` 升级

## `1.1.0` 之前

- 观察 `1.1.0-rc1` 在真实机器上运行多日
- 核心流程中无公开的 P0/P1 bug
- 更新发布说明
- RC 和每日标签不得更新 Homebrew
- 验证 DMG、appcast 和 Homebrew 更新仅在最终 `1.1.0` 时发生
