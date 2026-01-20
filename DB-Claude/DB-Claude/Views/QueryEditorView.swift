import SwiftUI
import SwiftData

struct QueryEditorView: View {
    let connection: Connection
    
    @State private var sql: String = "SELECT * FROM "
    @State private var results: [[String: String]] = []
    @State private var isExecuting: Bool = false
    @State private var errorMessage: String?
    @State private var executionTime: TimeInterval = 0
    
    // 自动补全数据
    @State private var tables: [String] = []
    @State private var columns: [String: [String]] = [:]
    
    // Toast 状态
    @State private var toastMessage: String?
    @State private var showToast: Bool = false
    
    // 字体大小
    @AppStorage("sqlEditorFontSize") private var fontSize: Double = 13
    
    // 执行的 SQL（用于显示是选中执行还是全部执行）
    @State private var executedSQL: String = ""
    
    // SQL 语法验证
    @State private var validationResult: SQLValidator.ValidationResult?
    
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        ZStack {
            VSplitView {
                // Editor Area
                VStack(spacing: 0) {
                    // 工具栏
                    queryToolbar
                    
                    // SQL 编辑器（带语法高亮和自动补全）
                    SQLTextView(
                        text: $sql,
                        tables: tables,
                        columns: columns,
                        fontSize: CGFloat(fontSize),
                        onExecute: { executeQuery(sql: sql) },
                        onExecuteSelected: { selectedSQL in
                            executeQuery(sql: selectedSQL)
                            showToastMessage("执行选中的 SQL")
                        },
                        onExplain: { sqlToExplain in
                            explainQuery(sql: sqlToExplain)
                        },
                        onFormat: {
                            formatSQL()
                        },
                        onShowToast: { message in
                            showToastMessage(message)
                        }
                    )
                    .background(AppColors.background)
                    
                    // SQL 语法错误提示
                    if let validation = validationResult, !validation.isValid {
                        sqlErrorHintsView(validation)
                    }
                }
                .background(AppColors.background)
                .frame(minHeight: 100)
                
                // Results Area
                VStack(alignment: .leading, spacing: 0) {
                    if let error = errorMessage {
                        AppErrorState(message: error)
                    } else {
                        EditableResultsGridView(results: results, tableName: "query_result", isEditable: false)
                        statusBar
                    }
                }
            }
            
            // Toast 提示
            if showToast, let message = toastMessage {
                VStack {
                    Spacer()
                    ToastView(message: message)
                        .padding(.bottom, 80)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: showToast)
            }
        }
        .onAppear {
            // 加载表和字段信息用于自动补全
            loadSchemaForCompletion()
        }
        .onChange(of: sql) { _, newValue in
            // 实时验证 SQL 语法
            validateSQL(newValue)
        }
    }
    
    // MARK: - SQL 语法验证
    private func validateSQL(_ sql: String) {
        validationResult = SQLValidator.validate(sql)
    }
    
    // MARK: - 语法错误提示视图
    private func sqlErrorHintsView(_ validation: SQLValidator.ValidationResult) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(validation.errors) { error in
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 11))
                        .foregroundColor(AppColors.warning)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(error.message)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(AppColors.warning)
                        
                        if let suggestion = error.suggestion {
                            Text("💡 " + suggestion)
                                .font(.system(size: 10))
                                .foregroundColor(AppColors.secondaryText)
                        }
                    }
                    
                    Spacer()
                }
            }
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.sm)
        .background(AppColors.warning.opacity(0.1))
        .overlay(
            Rectangle()
                .fill(AppColors.warning)
                .frame(width: 3),
            alignment: .leading
        )
    }
    
    // MARK: - 工具栏
    private var queryToolbar: some View {
        HStack(spacing: AppSpacing.sm) {
            // 运行按钮
            Button(action: { executeQuery(sql: sql) }) {
                HStack(spacing: AppSpacing.xs) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 10))
                    Text("运行")
                        .font(.system(size: 12, weight: .medium))
                }
            }
            .buttonStyle(AppPrimaryButtonStyle())
            .keyboardShortcut(.return, modifiers: .command)
            .disabled(isExecuting)
            
            // 清空按钮
            Button(action: { sql = "" }) {
                Image(systemName: "trash")
            }
            .buttonStyle(AppIconButtonStyle())
            .help("清空")
            
            // 格式化按钮
            Button(action: formatSQL) {
                Image(systemName: "text.alignleft")
            }
            .buttonStyle(AppIconButtonStyle())
            .keyboardShortcut("f", modifiers: [.command, .shift])
            .help("格式化 SQL (⌘⇧F)")
            
            AppDivider(axis: .vertical)
                .frame(height: 20)
            
            // 字体大小控制
            HStack(spacing: 4) {
                Button {
                    if fontSize > 10 {
                        fontSize -= 1
                    }
                } label: {
                    Image(systemName: "textformat.size.smaller")
                        .font(.system(size: 10))
                        .foregroundColor(AppColors.secondaryText)
                }
                .buttonStyle(.plain)
                .disabled(fontSize <= 10)
                
                Text("\(Int(fontSize))")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(AppColors.secondaryText)
                    .frame(width: 20)
                
                Button {
                    if fontSize < 24 {
                        fontSize += 1
                    }
                } label: {
                    Image(systemName: "textformat.size.larger")
                        .font(.system(size: 10))
                        .foregroundColor(AppColors.secondaryText)
                }
                .buttonStyle(.plain)
                .disabled(fontSize >= 24)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(AppColors.hover)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.sm))
            .help("字体大小")
            
            Spacer()
            
            // 提示信息
            Text("Tab 补全 | ⌘↩ 执行 | 选中后执行")
                .font(.system(size: 10))
                .foregroundColor(AppColors.tertiaryText)
            
            // 执行状态
            if isExecuting {
                HStack(spacing: AppSpacing.xs) {
                    ProgressView()
                        .controlSize(.small)
                    Text("执行中...")
                        .font(.system(size: 11))
                        .foregroundColor(AppColors.secondaryText)
                }
            }
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.sm)
        .background(AppColors.secondaryBackground)
    }
    
    // MARK: - 状态栏
    private var statusBar: some View {
        AppStatusBar(items: statusItems) {
            EmptyView()
        }
    }
    
    private var statusItems: [StatusItem] {
        var items: [StatusItem] = [
            StatusItem("\(results.count) 行", icon: "list.number")
        ]
        if executionTime > 0 {
            items.append(StatusItem(String(format: "%.3f 秒", executionTime), icon: "clock"))
        }
        return items
    }
    
    // MARK: - 加载 Schema 用于自动补全
    private func loadSchemaForCompletion() {
        Task {
            do {
                let driver = try await createDriver()
                try await driver.connect()
                
                // 获取表列表
                let tableList = try await driver.fetchTables()
                
                // 获取每个表的字段
                var columnMap: [String: [String]] = [:]
                for table in tableList {
                    do {
                        let ddl = try await driver.getDDL(for: table)
                        let cols = parseColumnsFromDDL(ddl)
                        columnMap[table] = cols
                    } catch {
                        // 忽略单个表的错误
                    }
                }
                
                await driver.disconnect()
                
                await MainActor.run {
                    self.tables = tableList
                    self.columns = columnMap
                }
            } catch {
                print("[QueryEditor] 加载 Schema 失败: \(error)")
            }
        }
    }
    
    // 从 DDL 解析字段名
    private func parseColumnsFromDDL(_ ddl: String) -> [String] {
        var columns: [String] = []
        
        // 简单解析：查找括号内的字段定义
        if let startRange = ddl.range(of: "("),
           let endRange = ddl.range(of: ")", options: .backwards) {
            let content = String(ddl[startRange.upperBound..<endRange.lowerBound])
            let lines = content.components(separatedBy: ",")
            
            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                // 跳过约束定义
                let upperLine = trimmed.uppercased()
                if upperLine.hasPrefix("PRIMARY") || upperLine.hasPrefix("FOREIGN") ||
                   upperLine.hasPrefix("UNIQUE") || upperLine.hasPrefix("CHECK") ||
                   upperLine.hasPrefix("CONSTRAINT") || upperLine.hasPrefix("INDEX") ||
                   upperLine.hasPrefix("KEY") {
                    continue
                }
                
                // 提取字段名（第一个单词或反引号内的内容）
                if let columnName = extractColumnName(from: trimmed) {
                    columns.append(columnName)
                }
            }
        }
        
        return columns
    }
    
    private func extractColumnName(from line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        
        // 反引号包裹的字段名
        if trimmed.hasPrefix("`") {
            if let endIndex = trimmed.dropFirst().firstIndex(of: "`") {
                return String(trimmed[trimmed.index(after: trimmed.startIndex)..<endIndex])
            }
        }
        
        // 双引号包裹的字段名
        if trimmed.hasPrefix("\"") {
            if let endIndex = trimmed.dropFirst().firstIndex(of: "\"") {
                return String(trimmed[trimmed.index(after: trimmed.startIndex)..<endIndex])
            }
        }
        
        // 普通字段名（第一个空格前的内容）
        if let spaceIndex = trimmed.firstIndex(of: " ") {
            return String(trimmed[..<spaceIndex])
        }
        
        return nil
    }
    
    // MARK: - 格式化 SQL
    private func formatSQL() {
        guard !sql.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        var formatted = sql
        
        // 关键字列表（按长度降序排列，避免短关键字替换长关键字的一部分）
        let keywords = [
            "ORDER BY", "GROUP BY", "LEFT JOIN", "RIGHT JOIN", "INNER JOIN", "OUTER JOIN",
            "CROSS JOIN", "NATURAL JOIN", "INSERT INTO", "CREATE TABLE", "ALTER TABLE",
            "DROP TABLE", "CREATE INDEX", "DROP INDEX", "PRIMARY KEY", "FOREIGN KEY",
            "SELECT", "UPDATE", "DELETE", "INSERT", "CREATE", "ALTER", "DROP",
            "FROM", "WHERE", "AND", "OR", "NOT", "IN", "BETWEEN", "LIKE",
            "JOIN", "LEFT", "RIGHT", "INNER", "OUTER", "ON", "USING",
            "HAVING", "LIMIT", "OFFSET", "UNION", "EXCEPT", "INTERSECT",
            "INTO", "VALUES", "SET", "AS", "DISTINCT", "ALL",
            "ASC", "DESC", "NULL", "IS", "EXISTS", "CASE", "WHEN", "THEN", "ELSE", "END"
        ]
        
        // 关键字大写
        for keyword in keywords {
            let pattern = "\\b\(keyword)\\b"
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                formatted = regex.stringByReplacingMatches(
                    in: formatted,
                    range: NSRange(formatted.startIndex..., in: formatted),
                    withTemplate: keyword
                )
            }
        }
        
        // 清理多余空格
        while formatted.contains("  ") {
            formatted = formatted.replacingOccurrences(of: "  ", with: " ")
        }
        
        // 在主要关键字前添加换行
        let newlineKeywords = [
            "FROM", "WHERE", "AND", "OR", "ORDER BY", "GROUP BY",
            "HAVING", "LIMIT", "OFFSET",
            "LEFT JOIN", "RIGHT JOIN", "INNER JOIN", "OUTER JOIN", "CROSS JOIN", "JOIN",
            "UNION", "EXCEPT", "INTERSECT",
            "SET", "VALUES"
        ]
        
        for keyword in newlineKeywords {
            // 替换 " KEYWORD " 为 "\nKEYWORD "
            formatted = formatted.replacingOccurrences(of: " \(keyword) ", with: "\n\(keyword) ")
            // 处理开头的情况
            if formatted.hasPrefix("\(keyword) ") {
                // 不处理
            }
        }
        
        // 清理开头的换行
        formatted = formatted.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 添加适当的缩进
        var lines = formatted.components(separatedBy: "\n")
        let indentString = "    "
        
        for i in 0..<lines.count {
            let trimmedLine = lines[i].trimmingCharacters(in: .whitespaces)
            let upperLine = trimmedLine.uppercased()
            
            // 减少缩进的关键字
            if upperLine.hasPrefix("FROM") || upperLine.hasPrefix("WHERE") ||
               upperLine.hasPrefix("ORDER BY") || upperLine.hasPrefix("GROUP BY") ||
               upperLine.hasPrefix("HAVING") || upperLine.hasPrefix("LIMIT") {
                // 保持与 SELECT 同级
            } else if upperLine.hasPrefix("AND") || upperLine.hasPrefix("OR") {
                // 缩进
                lines[i] = indentString + trimmedLine
            } else if upperLine.hasPrefix("JOIN") || upperLine.contains("JOIN ") {
                // JOIN 缩进
                lines[i] = indentString + trimmedLine
            }
        }
        
        sql = lines.joined(separator: "\n")
        showToastMessage("SQL 已格式化")
    }

    private func executeQuery(sql sqlToExecute: String) {
        guard !sqlToExecute.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        isExecuting = true
        errorMessage = nil
        results = []
        executedSQL = sqlToExecute
        let startTime = Date()
        
        Task {
            var finalStatus = "Success"
            var driver: (any DatabaseDriver)?
            do {
                driver = try await createDriver()
                try await driver?.connect()

                let rows = try await driver?.execute(sql: sqlToExecute) ?? []
                
                await MainActor.run {
                    self.results = rows
                    self.executionTime = Date().timeIntervalSince(startTime)
                    self.isExecuting = false
                }
            } catch {
                finalStatus = "Error"
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isExecuting = false
                }
            }

            // 关闭连接
            if let driver = driver {
                await driver.disconnect()
            }

            // Save History
            let time = Date().timeIntervalSince(startTime)
            let connID = connection.id
            let dbName = connection.databaseName
            
            await MainActor.run {
                let history = QueryHistory(
                    sql: sqlToExecute,
                    executionTime: time,
                    status: finalStatus,
                    connectionID: connID,
                    databaseName: dbName
                )
                modelContext.insert(history)
            }
        }
    }
    
    /// EXPLAIN 查询 - 显示执行计划
    private func explainQuery(sql sqlToExplain: String) {
        guard !sqlToExplain.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        // 构建 EXPLAIN 语句
        let trimmedSQL = sqlToExplain.trimmingCharacters(in: .whitespacesAndNewlines)
        let explainSQL: String
        
        // 检查是否已经是 EXPLAIN 语句
        if trimmedSQL.uppercased().hasPrefix("EXPLAIN") {
            explainSQL = trimmedSQL
        } else {
            explainSQL = "EXPLAIN " + trimmedSQL
        }
        
        // 执行 EXPLAIN
        executeQuery(sql: explainSQL)
        showToastMessage("执行 EXPLAIN 查询")
    }
    
    // Simplification: Re-creating driver here. In a real app we'd share it.
    private func createDriver() async throws -> any DatabaseDriver {
        switch connection.type {
        case .sqlite:
            guard let path = connection.filePath else { throw DatabaseError.connectionFailed("No file path") }
            return SQLiteDriver(path: path, connectionId: connection.id, connectionName: connection.name)
        case .mysql:
            return RealMySQLDriver(connection: connection)
        default:
            throw DatabaseError.connectionFailed("Unsupported driver")
        }
    }
    
    // MARK: - Toast 显示
    private func showToastMessage(_ message: String) {
        toastMessage = message
        withAnimation {
            showToast = true
        }
        
        // 2秒后自动隐藏
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                showToast = false
            }
        }
    }
}

// MARK: - Toast 视图组件
struct ToastView: View {
    let message: String
    
    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: "keyboard")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.9))
            
            Text(message)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white)
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.vertical, AppSpacing.sm)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.85))
                .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
        )
    }
}
