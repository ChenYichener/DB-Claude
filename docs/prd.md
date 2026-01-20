你好！很高兴能以架构师的身份为你提供方案。

开发一个原生的 macOS 数据库管理工具是一个非常棒的挑战。使用 Swift 和 SwiftUI（或 AppKit）可以获得极致的性能和原生丝滑的体验，这在处理大量数据时比 Electron 应用（如 TablePlus 的某些竞争对手）更有优势。

以下我为你设计的详细产品需求文档（PRD）、架构设计及分阶段开发路线图。

---

## 一、 产品概述 (PRD)

**目标：** 打造一款轻量级、原生、智能化的 SQL 客户端，核心竞争力在于 **“原生性能”** 与 **“AI 深度集成”**。

### 1. 核心功能点

* **连接管理：** 支持主流数据库（MySQL, PostgreSQL, SQLite），支持连接参数持久化，支持 JSON 格式导入/导出。
* **结构浏览：** 左侧树形结构展现“连接 -> 数据库 -> 表/查询”，支持查看表 DDL。
* **查询编辑器：** 多标签页设计，支持 SQL 高亮、选中执行、快捷键操作（如 `Cmd + Enter`）。
* **执行历史：** 右侧侧边栏记录每次执行的时间、SQL 语句、耗时、状态。
* **AI 增强：** * **智能补全：** 基于当前连接的表名、字段名进行 Context-aware 补全。
* **NL2SQL：** 自然语言转 SQL，仅发送 Schema 信息至 AI，保护数据隐私。


* **结果处理：** 数据分页显示，支持导出为 CSV/JSON。

### 2. UI 布局 (参考 Navicat)

* **Top:** 工具栏（新建连接、运行、停止、导出）。
* **Left:** `NavigationSplitView` 左侧树（三级结构）。
* **Center:** `TabView` 区域，包含 SQL 编辑器和底部的 Data Grid。
* **Right:** 可折叠的历史记录面板。

---

## 二、 技术方案架构

为了保证扩展性和性能，建议采用 **分层架构**：

### 1. 技术栈选型

* **UI 框架：** SwiftUI (配合 `NavigationSplitView` 和 `Table`)。
* **底层驱动：** * SQLite: 内建支持。
* MySQL/PostgreSQL: 使用 C 库的 Swift 封装（如 `MySQLNIO` 或直接集成 `libmysqlclient`）。


* **代码编辑器：** 推荐集成 `Runestone` 或 `STTextView`（原生高性能文本组件，支持语法高亮）。
* **本地存储：** `CoreData` 或 `SwiftData`（用于保存连接信息、查询历史）。
* **AI 引擎：** OpenAI API 或 Anthropic，通过 **Context Manager** 提取表结构。

### 2. 关键设计：AI 安全保障

为了确保安全，**严禁将数据库真实数据发送给 AI**。

* **Schema 抽样：** 仅提取 `CREATE TABLE` 语句或字段名、类型、注释。
* **脱敏传输：** 发送至 LLM 前，去除敏感字段的 Default Value 或特定业务注释。

---

## 三、 详细开发路线图

### 阶段一：骨架搭建与基础连接 (MVP - 第 1-2 周)

**目标：能够跑通连接流程并看到数据表。**

1. **UI 框架搭建：** 实现三栏布局（Sidebar, Detail, Inspector）。
2. **数据模型：** 定义 `Connection` 模型（Host, Port, User, Password, SSL）。
3. **连接管理：** * 实现连接的新增、保存（存入 Keychain 以保证密码安全）。
* 实现连接的 JSON 导入导出（使用 `Codable`）。


4. **数据库驱动集成：** 先集成一种（如 SQLite 或 MySQL），实现 `testConnection` 和获取表列表的功能。
5. **DDL 查看器：** 点击表，在主视图展示生成的 `SHOW CREATE TABLE` 结果。

### 阶段二：查询引擎与编辑器 (第 3-4 周)

**目标：像 Navicat 一样执行 SQL。**

1. **多标签管理：** 实现 Tab 系统，每个 Tab 维护自己的连接上下文。
2. **SQL 编辑器集成：** 集成原生编辑器组件，实现基本的 SQL 语法高亮。
3. **执行引擎：**
* 异步执行 SQL，避免 UI 卡死。
* 实现“选中部分代码执行”逻辑。


4. **结果集渲染：** 使用 `Table` 或高性能的 Lazy Grid 渲染查询结果。
5. **结果导出：** 实现将 Grid 数据转换为 CSV 文件的逻辑。

### 阶段三：历史记录与交互优化 (第 5 周)

**目标：完善细节体验。**

1. **历史面板：**
* 每次点击“运行”后，将 SQL、时间戳、成功状态写入 `CoreData`。
* 点击历史记录，可将其重新填充回当前编辑器。


2. **快捷键支持：** 绑定 `Cmd+Enter` 执行 SQL，`Cmd+T` 新建查询。
3. **UI 抛光：** 增加连接状态的 Icon（绿色在线、灰色离线），增加运行时的 Loading 动画。

### 阶段四：AI 智能体集成 (第 6-8 周)

**目标：差异化竞争核心功能。**

1. **Schema 解析器：** 编写一个 Service，自动抓取当前数据库的所有表结构，构建一个本地的 `SchemaContext`。
2. **智能补全：**
* 拦截编辑器输入，匹配 `SchemaContext` 中的表名和字段。


3. **自然语言转 SQL (NL2SQL)：**
* 提供一个 Prompt 模板，将用户的问题 + `SchemaContext` 发送给 AI。
* **安全层：** 校验 AI 返回的语句，防止生成 `DROP`, `DELETE` 等高危操作（可配置只读模式）。


4. **AI 对话框：** 在编辑器上方或右侧提供一个输入框：“我想看最近 10 条订单的详情”。

---

## 四、 核心代码设计思路 (示例)

### 1. 数据库驱动抽象 (Protocol)

为了支持多数据库，你需要定义一个协议：

```swift
protocol DatabaseDriver {
    func connect() async throws -> Bool
    func execute(sql: String) async throws -> SQLResultSet
    func fetchTables() async throws -> [String]
    func generateDDL(for table: String) async throws -> String
}

```

### 2. AI Prompt 设计示例

```text
Context:
The database has following tables:
- orders (id, user_id, amount, created_at)
- users (id, name, email)

Task:
Generate a SQL query for: "Show me the top 5 users with highest order amounts"

Constraint:
Only return SQL. No explanation. Use standard SQL syntax.

```

---

## 五、 后续扩展建议 (阶段 N)

* **数据可视化：** 针对查询结果，一键生成简单的柱状图或折线图。
* **多环境管理：** 区分开发、测试、生产环境，生产环境执行 SQL 时增加二次确认。
* **插件系统：** 允许用户通过 JS 编写自己的数据处理插件。

**下一步建议：**
我们可以先从**阶段一的连接管理模型和左侧树形结构**开始。你希望先详细看哪一部分的代码实现或技术选型（比如：如何用 Swift 实现高性能的 Data Grid）？