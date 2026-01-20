import SwiftUI
import SwiftData

struct QueryEditorView: View {
    let connection: Connection
    
    @State private var sql: String = "SELECT * FROM sqlite_master;"
    @State private var results: [[String: String]] = []
    @State private var isExecuting: Bool = false
    @State private var errorMessage: String?
    @State private var executionTime: TimeInterval = 0
    
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        VSplitView {
            // Editor Area - 扁平化设计
            VStack(spacing: 0) {
                // 工具栏
                queryToolbar
                
                // SQL 编辑器
                TextEditor(text: $sql)
                    .font(.system(.body, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .background(AppColors.background)
                    .padding(AppSpacing.sm)
            }
            .background(AppColors.background)
            .frame(minHeight: 100)
            
            // Results Area - 扁平化设计
            VStack(alignment: .leading, spacing: 0) {
                if let error = errorMessage {
                    errorView(error)
                } else {
                    EditableResultsGridView(results: results, tableName: "query_result", isEditable: false)
                    statusBar
                }
            }
        }
        .onAppear {
            // Pre-fill SQL if generic
            if sql == "SELECT * FROM sqlite_master;" && connection.type != .sqlite {
                sql = "SELECT 1;"
            }
        }
    }
    
    // MARK: - 工具栏
    private var queryToolbar: some View {
        HStack(spacing: AppSpacing.sm) {
            // 运行按钮
            Button(action: executeQuery) {
                HStack(spacing: AppSpacing.xs) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 10))
                    Text("运行")
                        .font(.system(size: 12, weight: .medium))
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, AppSpacing.sm)
                .background(AppColors.accent)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.return, modifiers: .command)
            .disabled(isExecuting)
            
            // 清空按钮
            Button(action: { sql = "" }) {
                Image(systemName: "trash")
                    .font(.system(size: 12))
                    .foregroundColor(AppColors.secondaryText)
                    .frame(width: 28, height: 28)
                    .background(AppColors.hover)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.sm))
            }
            .buttonStyle(.plain)
            
            Spacer()
            
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
    
    // MARK: - 错误视图
    private func errorView(_ error: String) -> some View {
        ScrollView {
            HStack(alignment: .top, spacing: AppSpacing.sm) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(AppColors.error)
                    .font(.system(size: 14))
                
                Text(error)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(AppColors.error)
                    .textSelection(.enabled)
            }
            .padding(AppSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(AppColors.error.opacity(0.05))
    }
    
    // MARK: - 状态栏
    private var statusBar: some View {
        HStack(spacing: AppSpacing.md) {
            // 行数
            HStack(spacing: AppSpacing.xs) {
                Image(systemName: "list.number")
                    .font(.system(size: 10))
                Text("\(results.count) 行")
            }
            
            // 执行时间
            if executionTime > 0 {
                HStack(spacing: AppSpacing.xs) {
                    Image(systemName: "clock")
                        .font(.system(size: 10))
                    Text(String(format: "%.3f 秒", executionTime))
                }
            }
            
            Spacer()
        }
        .font(.system(size: 11))
        .foregroundColor(AppColors.secondaryText)
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.sm)
        .background(AppColors.secondaryBackground)
    }
    
    private func executeQuery() {
        guard !sql.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        isExecuting = true
        errorMessage = nil
        results = []
        let startTime = Date()
        
        Task {
            var finalStatus = "Success"
            var driver: (any DatabaseDriver)?
            do {
                driver = try await createDriver()
                try await driver?.connect()

                let rows = try await driver?.execute(sql: sql) ?? []
                
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
            let sqlToSave = sql
            let connID = connection.id
            let dbName = connection.databaseName
            
            await MainActor.run {
                let history = QueryHistory(
                    sql: sqlToSave,
                    executionTime: time,
                    status: finalStatus,
                    connectionID: connID,
                    databaseName: dbName
                )
                modelContext.insert(history)
            }
        }
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
}
