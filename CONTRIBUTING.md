# 贡献 DavyWhisper

感谢您对贡献的兴趣！

## 开始

1. Fork 仓库并克隆
2. 用 Xcode 16+ 打开 `DavyWhisper.xcodeproj`
3. 首次构建时 SPM 依赖自动解析
4. 构建并运行（Cmd+R）— 应用显示为菜单栏图标

## 代码签名（可选）

项目使用临时签名（ad-hoc signing）无需任何签名设置即可构建。

使用自己的签名身份：
```
echo 'DEVELOPMENT_TEAM = YOUR_TEAM_ID' > CodeSigning.local.xcconfig
```

## 开发环境

- 需要 **macOS 15.0+**
- **Swift 6** 严格并发模式
- Debug 构建使用独立数据目录（`DavyWhisper-Dev`）和 keychain 前缀，不干扰 Release 构建

## Pull Request

1. 从 `main` 创建功能分支
2. 保持更改专注 — 一个 PR 一个功能或修复
3. 手动测试更改并运行自动化检查
4. 填写 PR 模板（Summary + Test Plan）
5. PR 以 squash merge 方式合并到 `main`

推荐检查项：

```bash
xcodebuild test -project DavyWhisper.xcodeproj -scheme DavyWhisper -destination 'platform=macOS,arch=arm64' -parallel-testing-enabled NO CODE_SIGN_IDENTITY='-' CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO
swift test --package-path DavyWhisperPluginSDK
```

## 代码风格

- 遵循代码库中的现有模式
- MVVM 架构，配合 `ServiceContainer` 进行依赖注入
- 本地化：所有面向用户的字符串使用 `String(localized:)`
- 使用 SwiftData 持久化，Combine 处理响应式更新

## 报告问题

使用 [issue 模板](https://github.com/DavyWhisper/davywhisper-mac/issues/new/choose) 报告 bug 和功能请求。

## 许可证

通过贡献，您同意您的贡献将在 GPLv3 下获得许可。
