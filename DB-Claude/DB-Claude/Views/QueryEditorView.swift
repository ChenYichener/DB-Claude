import SwiftUI
import SwiftData

struct QueryEditorView: View {
    let connection: Connection
    let tabId: UUID
    let initialDatabase: String
    @Bindable var tabManager: TabManager
    
    @State private var sql: String = ""
    @State private var results: [[String: String]] = []
    @State private var isExecuting: Bool = false
    @State private var errorMessage: String?
    @State private var executionTime: TimeInterval = 0
    
    // 当前选择的数据库
    @State private var selectedDatabase: String = ""
    @State private var availableDatabases: [String] = []
    
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
    
    // 危险操作权限开关
    @State private var allowUpdate: Bool = false
    @State private var allowDelete: Bool = false
    @State private var allowAlter: Bool = false
    
    // UPDATE/DELETE 确认弹框
    @State private var showUpdateConfirm: Bool = false
    @State private var pendingSQL: String = ""
    @State private var affectedRowCount: Int = 0
    @State private var previewSelectSQL: String = ""
    
    // SQL 语法验证
    @State private var validationResult: SQLValidator.ValidationResult?
    
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        ZStack {
            VSplitView {
                editorArea
                resultsArea
            }
            
            // Toast 提示
            if showToast, let message = toastMessage {
                toastOverlay(message: message)
            }
        }
        .onAppear {
            selectedDatabase = initialDatabase
            loadDatabaseList()
            loadSchemaForCompletion()
        }
        .onChange(of: selectedDatabase) { _, newValue in
            // 更新 TabManager 中的数据库名
            tabManager.updateTabDatabase(id: tabId, databaseName: newValue)
            // 重新加载 Schema
            loadSchemaForCompletion()
        }
        .onChange(of: sql) { _, newValue in
            validateSQL(newValue)
        }
        .sheet(isPresented: $showUpdateConfirm) {
            UpdateConfirmView(
                sql: pendingSQL,
                previewSQL: previewSelectSQL,
                affectedCount: affectedRowCount,
                onConfirm: { confirmAndExecute() },
                onCancel: {
                    showUpdateConfirm = false
                    pendingSQL = ""
                }
            )
        }
    }
    
    // MARK: - 主要视图区域
    
    private var editorArea: some View {
        VStack(spacing: 0) {
            queryToolbar
            
            SQLTextView(
                text: $sql,
                tables: tables,
                columns: columns,
                fontSize: CGFloat(fontSize),
                onExecute: { executeQuery(sql: sql) },
                onExecuteSelected: { selectedSQL in
                    executeQuery(sql: selectedSQL)
                },
                onExplain: { sqlToExplain in
                    explainQuery(sql: sqlToExplain)
                },
                onFormat: { formatSQL() },
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
    }
    
    private var resultsArea: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let error = errorMessage {
                AppErrorState(message: error)
            } else {
                EditableResultsGridView(results: results, tableName: "query_result", isEditable: false)
                statusBar
            }
        }
    }
    
    private func toastOverlay(message: String) -> some View {
        VStack {
            Spacer()
            ToastView(message: message)
                .padding(.bottom, 80)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: showToast)
    }
    
    // MARK: - SQL 语法验证
    
    private func validateSQL(_ sql: String) {
        validationResult = SQLValidator.validate(sql)
    }
    
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
        HStack(spacing: AppSpacing.md) {
            // 连接和数据库选择器
            connectionDatabaseSelector
            
            AppDivider(axis: .vertical)
                .frame(height: 24)
            
            runButton
            clearButton
            formatButton
            
            AppDivider(axis: .vertical)
                .frame(height: 24)
            
            fontSizeControls
            
            AppDivider(axis: .vertical)
                .frame(height: 24)
            
            dangerousOperationToggles
            
            Spacer()
            
            keyboardHints
            executingIndicator
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.vertical, AppSpacing.md)
        .background(.ultraThinMaterial)
    }
    
    // MARK: - 连接和数据库选择器
    
    private var connectionDatabaseSelector: some View {
        HStack(spacing: AppSpacing.sm) {
            // 连接名称（只读显示）
            HStack(spacing: AppSpacing.xs) {
                Image(systemName: connectionIcon)
                    .font(.system(size: 11))
                    .foregroundColor(AppColors.accent)
                Text(connection.name)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AppColors.primaryText)
            }
            .padding(.horizontal, AppSpacing.sm)
            .padding(.vertical, AppSpacing.xs)
            .background(AppColors.secondaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.sm))
            
            // 数据库选择器
            if !availableDatabases.isEmpty {
                Picker("", selection: $selectedDatabase) {
                    if selectedDatabase.isEmpty {
                        Text("选择数据库").tag("")
                    }
                    ForEach(availableDatabases, id: \.self) { db in
                        Text(db).tag(db)
                    }
                }
                .pickerStyle(.menu)
                .frame(minWidth: 120)
                .labelsHidden()
            } else {
                Text(selectedDatabase.isEmpty ? "无数据库" : selectedDatabase)
                    .font(.system(size: 12))
                    .foregroundColor(AppColors.secondaryText)
                    .padding(.horizontal, AppSpacing.sm)
                    .padding(.vertical, AppSpacing.xs)
                    .background(AppColors.secondaryBackground)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.sm))
            }
        }
    }
    
    private var connectionIcon: String {
        switch connection.type {
        case .sqlite: return "cylinder.split.1x2"
        case .mysql: return "cylinder.split.1x2.fill"
        case .postgresql: return "cylinder"
        }
    }
    
    private var runButton: some View {
        Button(action: { executeQuery(sql: sql) }) {
            HStack(spacing: AppSpacing.xs) {
                Image(systemName: "play.fill")
                    .font(.system(size: 11))
                Text("运行")
                    .font(AppTypography.captionMedium)
            }
        }
        .buttonStyle(AppPrimaryButtonStyle())
        .keyboardShortcut(.return, modifiers: .command)
        .disabled(isExecuting)
    }
    
    private var clearButton: some View {
        Button(action: { sql = "" }) {
            Image(systemName: "trash")
        }
        .buttonStyle(AppIconButtonStyle())
    }
    
    private var formatButton: some View {
        Button(action: formatSQL) {
            Image(systemName: "text.alignleft")
        }
        .buttonStyle(AppIconButtonStyle())
        .keyboardShortcut("f", modifiers: [.command, .shift])
    }
    
    private var fontSizeControls: some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: "textformat.size")
                .font(.system(size: 11))
                .foregroundColor(AppColors.secondaryText)
            
            // 紧凑滑块
            Slider(value: $fontSize, in: 10...24, step: 1)
                .frame(width: 80)
                .controlSize(.mini)
            
            // 数字显示（支持滚轮调整）
            Text("\(Int(fontSize))")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(AppColors.primaryText)
                .frame(width: 20)
                .onScrollWheel { delta in
                    let newSize = fontSize + delta
                    fontSize = min(24, max(10, newSize))
                }
        }
        .padding(.horizontal, AppSpacing.sm)
        .padding(.vertical, AppSpacing.xs)
        .background(AppColors.hover)
        .clipShape(Capsule())
        .help("字体大小: \(Int(fontSize))pt (滚轮可调整)")
    }
    
    private var dangerousOperationToggles: some View {
        HStack(spacing: AppSpacing.sm) {
            DangerToggle(title: "UPDATE", isOn: $allowUpdate, color: .orange)
            DangerToggle(title: "DELETE", isOn: $allowDelete, color: .red)
            DangerToggle(title: "ALTER", isOn: $allowAlter, color: .purple)
        }
    }
    
    private var keyboardHints: some View {
        HStack(spacing: AppSpacing.xs) {
            Image(systemName: "keyboard")
                .font(.system(size: 10))
                .foregroundColor(AppColors.tertiaryText)

            Text("Tab 补全 | 选中后执行")
                .font(AppTypography.small)
                .foregroundColor(AppColors.tertiaryText)
        }
    }
    
    @ViewBuilder
    private var executingIndicator: some View {
        if isExecuting {
            HStack(spacing: AppSpacing.xs) {
                ProgressView()
                    .controlSize(.small)
                Text("执行中...")
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.secondaryText)
            }
        }
    }
    
    // MARK: - 状态栏
    
    private var statusBar: some View {
        AppStatusBar(items: statusItems) {
            EmptyView()
        }
    }
    
    private var statusItems: [StatusItem] {
        // 计算实际数据行数（减去元数据行）
        let dataRowCount = max(0, results.count - 1)
        var items: [StatusItem] = [
            StatusItem("\(dataRowCount) 行", icon: "list.number")
        ]
        if executionTime > 0 {
            items.append(StatusItem(String(format: "%.3f 秒", executionTime), icon: "clock"))
        }
        return items
    }
    
    // MARK: - 加载数据库列表
    
    private func loadDatabaseList() {
        Task {
            do {
                let driver = try await createDriverWithoutUseDatabase()
                try await driver.connect()
                
                let databases = try await driver.fetchDatabases()
                
                await driver.disconnect()
                
                await MainActor.run {
                    self.availableDatabases = databases
                }
            } catch {
                print("[QueryEditor] 加载数据库列表失败: \(error)")
            }
        }
    }
    
    // MARK: - 加载 Schema 用于自动补全
    
    private func loadSchemaForCompletion() {
        guard !selectedDatabase.isEmpty else { return }
        
        Task {
            do {
                let driver = try await createDriver()
                try await driver.connect()
                // 切换到选中的数据库
                try await driver.useDatabase(selectedDatabase)
                
                let tableList = try await driver.fetchTables()
                
                var columnMap: [String: [String]] = [:]
                for table in tableList {
                    do {
                        let ddl = try await driver.getDDL(for: table)
                        let cols = SQLFormatter.parseColumnsFromDDL(ddl)
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
    
    // MARK: - 格式化 SQL
    
    private func formatSQL() {
        sql = SQLFormatter.format(sql)
        showToastMessage("SQL 已格式化")
    }

    // MARK: - 执行查询
    
    private func executeQuery(sql sqlToExecute: String) {
        guard !sqlToExecute.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        // 检查危险操作权限
        if let blockedReason = SQLFormatter.checkDangerousOperation(
            sqlToExecute,
            allowUpdate: allowUpdate,
            allowDelete: allowDelete,
            allowAlter: allowAlter
        ) {
            errorMessage = blockedReason
            return
        }
        
        let upperSQL = sqlToExecute.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 检查是否是 UPDATE 或 DELETE 语句，需要预览确认
        if (upperSQL.hasPrefix("UPDATE ") && allowUpdate) || 
           (upperSQL.hasPrefix("DELETE ") && allowDelete) {
            previewAffectedRows(sql: sqlToExecute)
            return
        }
        
        executeQueryDirectly(sql: sqlToExecute)
    }
    
    private func previewAffectedRows(sql sqlToExecute: String) {
        isExecuting = true
        errorMessage = nil
        
        Task {
            do {
                let driver = try await createDriver()
                try await driver.connect()
                // 切换到选中的数据库
                if !selectedDatabase.isEmpty {
                    try await driver.useDatabase(selectedDatabase)
                }
                
                let countSQL = SQLFormatter.convertToCountQuery(sqlToExecute)
                let previewSQL = SQLFormatter.convertToPreviewQuery(sqlToExecute)
                
                var rowCount = 0
                if let countSQL = countSQL {
                    let countResult = try await driver.execute(sql: countSQL)
                    // 跳过第一行元数据行（__columns__），获取实际数据
                    let dataRows = countResult.dropFirst()
                    if let firstRow = dataRows.first,
                       let countValue = firstRow.values.first,
                       let count = Int(countValue) {
                        rowCount = count
                    }
                }
                
                await driver.disconnect()
                
                await MainActor.run {
                    self.isExecuting = false
                    self.pendingSQL = sqlToExecute
                    self.affectedRowCount = rowCount
                    self.previewSelectSQL = previewSQL ?? ""
                    self.showUpdateConfirm = true
                }
            } catch {
                await MainActor.run {
                    self.isExecuting = false
                    self.errorMessage = "预览失败: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func confirmAndExecute() {
        showUpdateConfirm = false
        executeQueryDirectly(sql: pendingSQL)
    }
    
    private func executeQueryDirectly(sql sqlToExecute: String) {
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
                // 切换到选中的数据库
                if !selectedDatabase.isEmpty {
                    try await driver?.useDatabase(selectedDatabase)
                }

                let rows = try await driver?.execute(sql: sqlToExecute) ?? []
                
                await MainActor.run {
                    print("[QueryEditor] 查询完成, rows=\(rows.count)")
                    if let first = rows.first {
                        print("[QueryEditor] 第一行: \(first)")
                    }
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
                cleanupOldHistory(for: connID, maxCount: 100)
            }
        }
    }
    
    private func explainQuery(sql sqlToExplain: String) {
        guard !sqlToExplain.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let trimmedSQL = sqlToExplain.trimmingCharacters(in: .whitespacesAndNewlines)
        let explainSQL: String
        
        if trimmedSQL.uppercased().hasPrefix("EXPLAIN") {
            explainSQL = trimmedSQL
        } else {
            explainSQL = "EXPLAIN " + trimmedSQL
        }
        
        executeQuery(sql: explainSQL)
        showToastMessage("执行 EXPLAIN 查询")
    }
    
    // MARK: - 驱动创建
    
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
    
    /// 创建驱动但不切换数据库（用于获取数据库列表）
    private func createDriverWithoutUseDatabase() async throws -> any DatabaseDriver {
        return try await createDriver()
    }
    
    /// 创建驱动并切换到选中的数据库
    private func createDriverAndUseDatabase() async throws -> any DatabaseDriver {
        let driver = try await createDriver()
        try await driver.connect()
        if !selectedDatabase.isEmpty {
            try await driver.useDatabase(selectedDatabase)
        }
        return driver
    }
    
    // MARK: - Toast 显示
    
    private func showToastMessage(_ message: String) {
        toastMessage = message
        withAnimation {
            showToast = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                showToast = false
            }
        }
    }
    
    // MARK: - 历史记录清理
    
    private func cleanupOldHistory(for connectionID: UUID, maxCount: Int) {
        let descriptor = FetchDescriptor<QueryHistory>(
            predicate: #Predicate { $0.connectionID == connectionID },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        
        do {
            let allHistory = try modelContext.fetch(descriptor)
            if allHistory.count > maxCount {
                for item in allHistory.dropFirst(maxCount) {
                    modelContext.delete(item)
                }
            }
        } catch {
            print("Failed to cleanup history: \(error)")
        }
    }
}
