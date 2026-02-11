# PomeloBot iOS App

PomeloBot 的 iOS 原生客户端，使用 SwiftUI 构建，通过 WebSocket 协议与 PomeloBot 后端通信。

## 架构

```
PomeloBot/
├── App/                    # App 入口
│   ├── PomeloBotApp.swift  # @main 入口
│   └── ContentView.swift   # Tab 主视图
├── Models/                 # 数据模型
│   ├── ProtocolTypes.swift # WebSocket 协议类型（对齐后端 ios/types.ts）
│   └── Message.swift       # 本地消息 & 会话模型
├── Services/               # 服务层
│   ├── WebSocketService.swift  # WebSocket 连接管理
│   └── SettingsStore.swift     # 用户设置持久化
├── ViewModels/             # 视图模型
│   └── ChatViewModel.swift # 聊天业务逻辑
├── Views/                  # UI 视图
│   ├── ChatView.swift          # 聊天主界面
│   ├── MessageBubbleView.swift # 消息气泡
│   ├── ConnectionStatusView.swift # 连接状态栏
│   └── SettingsView.swift      # 设置页面
├── Utils/                  # 工具类
│   └── HapticManager.swift # 触觉反馈
└── Assets.xcassets/        # 资源文件
```

## 协议对接

完整实现 PomeloBot iOS WebSocket 协议：

| 方向 | 消息类型 | 说明 |
|------|---------|------|
| Client → Server | `hello` | 握手认证（支持 authToken） |
| Client → Server | `message` | 发送聊天消息 |
| Client → Server | `ping` | 心跳保活 |
| Server → Client | `hello_ack` | 握手确认 |
| Server → Client | `hello_required` | 要求认证 |
| Server → Client | `dispatch_ack` | 消息派发确认 |
| Server → Client | `reply` | AI 回复 |
| Server → Client | `proactive` | 主动推送（定时任务等） |
| Server → Client | `pong` | 心跳响应 |
| Server → Client | `error` | 错误通知 |

## 技术栈

- **UI**: SwiftUI (iOS 26+) + **Liquid Glass** 液态玻璃设计
- **语言**: Swift 6.2
- **网络**: URLSessionWebSocketTask（原生，零依赖）
- **响应式**: Combine
- **并发**: Swift Concurrency (async/await)
- **持久化**: UserDefaults / AppStorage

## 功能特性

- [x] WebSocket 实时通信
- [x] 自动认证（hello + authToken）
- [x] 心跳保活（25s 间隔 ping）
- [x] 断线自动重连（指数退避，最大 10 次）
- [x] 多会话管理
- [x] 主动推送消息接收
- [x] 消息状态追踪（发送中/已发送/已送达/等待回复/错误）
- [x] 长按复制消息
- [x] 自定义字体大小
- [x] 深色/浅色模式切换
- [x] 触觉反馈

## iOS 26 Liquid Glass 适配

全面采用 WWDC 2025 发布的 Liquid Glass 设计语言：

| 组件 | Glass 效果 |
|------|-----------|
| **TabView** | 新 `Tab` API，底栏自动 Liquid Glass |
| **NavigationBar / Toolbar** | NavigationStack 自动 Glass 导航栏 |
| **消息气泡** | `.glassEffect()` + tint 区分用户/Bot 消息 |
| **输入栏** | 底部 Glass 面板 + Glass 圆形发送按钮 |
| **连接状态栏** | Glass 半透明状态条 + Glass 胶囊按钮 |
| **Typing 指示器** | Glass 胶囊动画 |
| **Bot 头像** | Glass 圆形头像 |
| **主动推送标签** | Glass 胶囊 Badge |

### 通用 Glass 组件 (`GlassComponents.swift`)

- `GlassCard` - 液态玻璃卡片容器
- `GlassBadge` - 液态玻璃胶囊标签
- `GlassFloatingButton` - 液态玻璃浮动按钮
- `GlassToolbarButton` - 液态玻璃工具栏按钮
- `MorphingGlassView` - 支持 morphing 动画的 Glass 容器
- `GlassEmptyState` - 空状态 Glass 视图

## 后端配置

在 PomeloBot 后端 `config.json` 中启用 iOS 通道：

```json
{
  "ios": {
    "enabled": true,
    "host": "0.0.0.0",
    "port": 18080,
    "path": "/ws/ios",
    "authToken": "your-secret-token",
    "debug": false,
    "pingIntervalMs": 30000
  }
}
```

启动后端 iOS 服务：

```bash
cd pomelobot
pnpm ios
```

## 构建运行

### 方式一：XcodeGen（推荐）

```bash
# 安装 XcodeGen
brew install xcodegen

# 生成 Xcode 项目
xcodegen generate

# 用 Xcode 打开
open PomeloBot.xcodeproj
```

### 方式二：手动 Xcode 项目

1. 打开 Xcode → File → New → Project → iOS App
2. Product Name: `PomeloBot`, Interface: `SwiftUI`, Language: `Swift`
3. 将 `PomeloBot/` 目录下的所有 `.swift` 文件拖入项目
4. 设置 Deployment Target 为 iOS 16.0
5. Build & Run

## App 使用

1. 在「设置」tab 中配置服务器地址（主机、端口、路径）
2. 如果后端启用了 authToken，填入对应的 Token
3. 切换到「对话」tab，点击「连接」按钮
4. 状态变为绿色「已认证」后即可开始对话
5. 支持创建多个会话，在左上角菜单切换
