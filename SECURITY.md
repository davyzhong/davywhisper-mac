# 安全策略

## 报告漏洞

如果您发现 DavyWhisper 中存在安全漏洞，请负责任地报告。

**不要公开创建 issue。** 请将安全问题发送至：**security@davywhisper.com**

您也可以使用 [GitHub 私人漏洞报告](https://github.com/DavyWhisper/davywhisper-mac/security/advisories/new)。

我们将在 48 小时内确认收到您的报告，并在 7 天内为关键问题提供修复方案。

## 范围

DavyWhisper 处理敏感数据，包括：
- 麦克风音频
- API 密钥（存储在 macOS Keychain 中）
- AppleScript 自动化（浏览器 URL 检测）
- 本地 HTTP API 服务器

这些领域的漏洞尤为重要。

## 安全边界

- 本地 HTTP API 仅绑定到 `127.0.0.1`。
- API 服务器默认禁用，必须在「设置」→「高级」中显式启用。
- API 密钥存储在 macOS Keychain 中，绝不能出现在导出的诊断信息中。
- 支持诊断以隐私安全的 JSON 报告形式导出，排除 API 密钥、音频负载和转写历史。

## 支持的版本

| 版本 | 支持 |
|------|------|
| 最新发布版本 | 是 |
| 当前预发布版本 / 预览构建 | 尽力而为 |
| 旧版本 | 否 |
