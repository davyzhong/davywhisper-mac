# DavyWhisper 插件

DavyWhisper 支持外部插件，形式为 macOS `.bundle` 文件。将编译后的 bundle 放置在：

```
~/Library/Application Support/DavyWhisper/Plugins/
```

## 插件类型

| 协议 | 用途 | 返回值？|
|------|------|:-------:|
| `DavyWhisperPlugin` | 基础协议，事件观察 | 否 |
| `PostProcessorPlugin` | 在管道中转换文本 | 是（处理后文本）|
| `LLMProviderPlugin` | 添加自定义 LLM 提供商 | 是（LLM 响应）|
| `TranscriptionEnginePlugin` | 自定义转写引擎 | 是（转写结果）|
| `ActionPlugin` | 将 LLM 输出路由到自定义操作（如创建 Linear issue）| 是（操作结果）|

## 事件总线

插件可以订阅事件，无需修改转写管道：

- `recordingStarted` — 录音开始
- `recordingStopped` — 录音结束（带时长）
- `transcriptionCompleted` — 转写完成（带完整数据）
- `transcriptionFailed` — 转写错误
- `textInserted` — 文本已插入目标应用
- `actionCompleted` — Action 插件执行完成（带结果数据）

## 创建插件

1. 在 Xcode 中创建新的 **macOS Bundle** target
2. 添加 `DavyWhisperPluginSDK` 作为包依赖
3. 实现 `DavyWhisperPlugin`（或子协议）
4. 将 `manifest.json` 添加到 `Contents/Resources/`
5. 构建并将 `.bundle` 复制到 Plugins 目录

### manifest.json

```json
{
    "id": "com.yourname.plugin-id",
    "name": "My Plugin",
    "version": "1.0.0",
    "minHostVersion": "1.0",
    "minOSVersion": "15.0",
    "author": "Your Name",
    "principalClass": "MyPluginClassName"
}
```

### 主机服务

每个插件接收提供以下功能的 `HostServices` 对象：

- **Keychain**：`storeSecret(key:value:)`、`loadSecret(key:)`
- **UserDefaults**（插件范围）：`userDefault(forKey:)`、`setUserDefault(_:forKey:)`
- **数据目录**：`pluginDataDirectory` — 持久化存储在 `~/Library/Application Support/DavyWhisper/PluginData/<pluginId>/`
- **应用上下文**：`activeAppBundleId`、`activeAppName`
- **配置文件**：`availableProfileNames` — 用户定义的配置文件名列表
- **事件总线**：`eventBus` 用于订阅事件
- **能力通知**：`notifyCapabilitiesChanged()` — 当插件状态变化时通知主机（如模型加载/卸载）

## 示例

参见 `WebhookPlugin/` 获取完整示例，演示如何在每次转写后发送 HTTP Webhook。
