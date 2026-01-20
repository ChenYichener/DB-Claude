# DB-Claude

一款原生 macOS 数据库管理工具，采用 Swift 和 SwiftUI 构建。

## 特性

- **多数据库支持**：SQLite（已实现）、MySQL（开发中）、PostgreSQL（规划中）
- **原生性能**：零第三方依赖，纯系统框架
- **现代化 UI**：基于 SwiftUI 的三栏布局设计
- **多标签页**：支持同时打开多个查询和表结构标签页
- **查询历史**：自动记录执行过的 SQL 语句

## 技术栈

- **语言**：Swift 5.0
- **UI 框架**：SwiftUI
- **数据持久化**：SwiftData
- **最低部署目标**：macOS 15.7

## 截图

*待添加*

## 开发

### 环境要求

- macOS 15.7+
- Xcode 16.0+

### 构建

```bash
# 命令行构建
xcodebuild -project DB-Claude.xcodeproj -scheme DB-Claude -configuration Debug build

# 或直接在 Xcode 中打开
open DB-Claude.xcodeproj
```

## 架构

项目采用 MVVM 分层架构：

```
Views (SwiftUI) → ViewModels (@Observable) → Models (@Model) → Services/Drivers
```

详细架构说明请参考 [CLAUDE.md](./CLAUDE.md)。

## 开发路线图

- [x] 阶段一：UI 骨架、连接管理、SQLite 驱动
- [x] 阶段二：多标签页、SQL 编辑器、结果网格
- [x] 阶段三：历史记录、快捷键
- [ ] 阶段四：AI 智能体集成、NL2SQL

## 许可证

MIT License
