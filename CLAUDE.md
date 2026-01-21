# CLAUDE.md

本文件为 Claude Code (claude.ai/code) 提供在 DB-Claude 代码库中工作的指导。

## 项目概述

DB-Claude 是一款原生 macOS 数据库管理工具，采用 Swift 和 SwiftUI 构建，核心特性包括：

- **多数据库支持**：SQLite（已实现）、MySQL（占位符）、PostgreSQL（规划中）
- **AI 深度集成**：智能补全和自然语言转 SQL（规划中）
- **原生性能**：零第三方依赖，纯系统框架

## 技术栈

- **语言**：Swift 5.0
- **UI 框架**：SwiftUI
- **数据持久化**：SwiftData
- **最低部署目标**：macOS 15.7
- **数据库驱动**：SQLite3（内建）、MySQL（待实现）

## 常用开发命令

### 构建和运行

```bash
# 命令行构建（需要 xcodebuild）
xcodebuild -project DB-Claude.xcodeproj -scheme DB-Claude -configuration Debug build

# 命令行运行（需要 open）
open DB-Claude.xcodeproj

# 清理构建
xcodebuild -project DB-Claude.xcodeproj -scheme DB-Claude clean
```

**注意**：本项目使用 Xcode 项目文件（非 Swift Package），推荐通过 Xcode GUI 进行开发。

### 测试

```bash
# 运行所有测试
xcodebuild test -project DB-Claude.xcodeproj -scheme DB-Claude -destination 'platform=macOS'

# 运行单元测试（当前无实际测试用例）
xcodebuild test -project DB-Claude.xcodeproj -scheme DB-Claude -only-testing:DB-ClaudeTests
```

**测试框架**：单元测试使用 Swift Testing 框架（非 XCTest），UI 测试使用 XCTest。

### 向项目添加新文件

项目包含辅助脚本 `update_project_phase2.py`，用于向 Xcode 项目批量添加文件。修改 `project.pbxproj` 时需注意：
- 每个文件需要唯一的 UUID
- 文件必须添加到 `PBXFileReference` 和 `PBXBuildFile` 段
- 更新 `PBXGroup` 的 `children` 数组
- 将源文件添加到 `PBXSourcesBuildPhase` 的 `files` 数组

## 架构概览

### 分层架构（MVVM）

```
┌─────────────────────────────────────────────────────────────┐
│                      Views (SwiftUI)                        │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐    │
│  │ Sidebar  │  │  Query   │  │ Results  │  │ History  │    │
│  │  View    │  │  Editor  │  │  Grid    │  │Inspector │    │
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘    │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│                   ViewModels (@Observable)                   │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  TabManager: 管理 workspace 标签页和选中状态          │   │
│  └──────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│                     Models (@Model)                         │
│  ┌──────────────────────┐  ┌──────────────────────────┐    │
│  │ Connection           │  │ QueryHistory             │    │
│  │ - host, port, user   │  │ - sql, timestamp,        │    │
│  │ - SwiftData 持久化   │  │   executionTime, status  │    │
│  └──────────────────────┘  └──────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│                   Services (Protocols)                      │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  DatabaseDriver 协议定义数据库抽象层                  │   │
│  │  - connect() / disconnect()                          │   │
│  │  - execute(sql:) / fetchTables() / getDDL(for:)      │   │
│  └──────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│                      Drivers (实现)                         │
│  ┌──────────────────────┐  ┌──────────────────────────┐    │
│  │ SQLiteDriver         │  │ MySQLDriver              │    │
│  │ - SQLite3 C API      │  │ - 占位符实现             │    │
│  │ - 完整实现           │  │ - 返回模拟数据           │    │
│  └──────────────────────┘  └──────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
```

### 主视图布局（ContentView）

使用 `NavigationSplitView` 实现三栏布局：

1. **左侧栏**：`SidebarView` - 连接树导航
   - 展开/折叠数据库列表
   - 异步加载数据库
   - 支持删除连接

2. **中间栏**：`TabView` - 工作区
   - `QueryEditorView`：SQL 编辑器 + 结果网格（VSplitView）
   - `StructureView`：表 DDL 查看器

3. **右侧栏**：`HistoryInspectorView` - 可折叠历史面板
   - 按时间倒序显示
   - 点击复制 SQL
   - 按连接 ID 过滤

### 状态管理模式

- **SwiftData**：使用 `@Query` 自动查询和监听 `Connection`、`QueryHistory`
- **环境注入**：`ModelContainer` 在 App 启动时初始化，通过 `@Environment(\.modelContext)` 传递
- **本地状态**：`@State` 和 `@Observable` 用于视图状态管理
- **异步操作**：所有数据库操作使用 `async/await`，UI 更新在 `MainActor`

### 标签页系统（TabManager）

```swift
enum TabType {
    case query                    // 查询标签页
    case structure(String)        // 表结构标签页（附表名）
}

struct WorkspaceTab {
    id: UUID
    title: String
    type: TabType
    connectionId: UUID
}
```

每个标签页维护独立的连接上下文，支持：
- `addQueryTab(connectionId:)` - 新建查询标签页
- `openStructureTab(table:connectionId:)` - 打开表结构标签页
- `closeTab(id:)` - 关闭标签页

## 命名约定

### 文件组织

- **视图**：`*View.swift`（如 `SidebarView.swift`）
- **模型**：`*.swift`（使用 `@Model` 宏，如 `Connection.swift`）
- **服务协议**：`*Service.swift`（如 `DatabaseService.swift`）
- **驱动实现**：`*Driver.swift`（如 `SQLiteDriver.swift`）
- **视图模型**：`*Manager.swift` 或 `*ViewModel.swift`（如 `TabManager.swift`）

### 代码风格

- **缩进**：4 空格（Swift 默认）
- **最大行宽**：无硬性限制（推荐 < 120 字符）
- **导入顺序**：系统框架 → 第三方框架（无）→ 本地模块
- **属性声明**：使用 `@Observable`、`@State`、`@Query` 等属性包装器管理状态

## 核心设计模式

### DatabaseDriver 协议

所有数据库驱动必须实现 `DatabaseDriver` 协议：

```swift
protocol DatabaseDriver {
    func connect() async throws
    func disconnect()
    func fetchDatabases() async throws -> [String]
    func fetchTables() async throws -> [String]
    func execute(sql: String) async throws -> [[String: String]]
    func getDDL(for table: String) async throws -> String
}
```

**实现要求**：
- 所有方法必须异步（`async`）避免阻塞 UI
- 错误通过 `throw` 抛出 `DatabaseError`
- `execute` 返回字典数组，首行为列名

### 异步操作规范

- 数据库操作必须在 `async` 上下文执行
- UI 更新通过 `MainActor.run { }` 或在 `@MainActor` 标记的视图进行
- 使用 `Task` 包装异步操作，支持取消

### 错误处理

```swift
enum DatabaseError: Error {
    case connectionFailed(String)
    case queryFailed(String)
    case notConnected
}
```

所有数据库错误必须抛出 `DatabaseError`，在 UI 层转换为用户友好的错误消息。

## SwiftUI 开发陷阱

开发过程中遇到的 SwiftUI 问题及解决方案：

- **ScrollView 事件传递问题**：详见 `/docs/swiftui-scrollview-pitfall.md`
- **NSTableView 单元格编辑问题**：详见 `/docs/nstableview-editing-pitfall.md`
- **NSTableView 数据显示问题**：详见 `/docs/nstableview-data-display-pitfall.md`

### ScrollView 事件传递问题

**问题**：`ScrollView` 内部的子视图可能无法接收 `onHover` 和点击事件，即使视图已正确渲染。

**解决方案**：
- 如果内容数量有限，**不要使用 ScrollView**，直接用 HStack/VStack
- 将不同场景的组件独立实现，避免复用导致的布局差异

```swift
// ❌ 避免：预防性使用 ScrollView
ScrollView(.horizontal) {
    HStack { ForEach(items) { ... } }
}

// ✅ 推荐：直接使用 HStack
HStack {
    ForEach(items) { ... }
    Spacer()
}
```

## 已知限制

1. **MySQL 驱动**：当前为占位符实现，返回假数据
2. **连接池**：每次查询都重新连接，无连接复用
3. **查询取消**：无法中断正在执行的查询
4. **结果导出**：无 CSV/JSON 导出功能
5. **测试覆盖**：无实际单元测试或 UI 测试

## 安全特性

### Keychain 密码存储

数据库连接密码使用 macOS Keychain 安全存储：

- **存储位置**：`Services/KeychainService.swift`
- **访问方式**：`Connection.getSecurePassword()` / `Connection.setSecurePassword(_:)`
- **自动迁移**：旧版明文密码会自动迁移到 Keychain

```swift
// 获取密码（自动处理迁移）
let password = connection.getSecurePassword()

// 设置密码
connection.setSecurePassword("new_password")

// 删除密码
connection.deleteSecurePassword()
```

**注意**：`Connection.password` 属性已废弃，新密码不再存储到 SwiftData。

## 产品需求参考

项目遵循 `/docs/prd.md` 定义的开发路线图：

- **阶段一**（已完成）：UI 骨架、连接管理、SQLite 驱动
- **阶段二**（已完成）：多标签页、SQL 编辑器、结果网格
- **阶段三**（已完成）：历史记录、快捷键
- **阶段四**（未开始）：AI 智能体集成、NL2SQL

## 重要注意事项

1. **安全原则**：严禁将数据库真实数据发送给 AI，仅传输 Schema 信息
2. **零依赖政策**：优先使用系统框架，避免引入第三方依赖
3. **破坏性更改**：不做向后兼容，重大更新直接修改
4. **中文优先**：所有文档、注释、提交信息使用简体中文
5. **MVVM 严格分层**：视图不直接访问服务层，必须通过 ViewModel 中转
