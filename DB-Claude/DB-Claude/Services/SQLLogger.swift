import Foundation
import Combine

// MARK: - SQL 执行记录
struct SQLLogEntry: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let connectionId: UUID?
    let connectionName: String
    let databaseType: String
    let sql: String
    let duration: TimeInterval
    let rowCount: Int?
    let success: Bool
    let errorMessage: String?
    
    init(connectionId: UUID?, connectionName: String, databaseType: String, 
         sql: String, duration: TimeInterval, rowCount: Int? = nil, 
         success: Bool = true, errorMessage: String? = nil) {
        self.id = UUID()
        self.timestamp = Date()
        self.connectionId = connectionId
        self.connectionName = connectionName
        self.databaseType = databaseType
        self.sql = sql
        self.duration = duration
        self.rowCount = rowCount
        self.success = success
        self.errorMessage = errorMessage
    }
}

// MARK: - SQL 日志管理器
@MainActor
class SQLLogger: ObservableObject {
    static let shared = SQLLogger()
    
    @Published private(set) var logs: [SQLLogEntry] = []
    
    // 配置：分类型限制日志数量
    private let maxSelectCount: Int = 500   // SELECT 语句最多保留 500 条
    private let maxOtherCount: Int = 500    // 其他语句最多保留 500 条
    private let logFilePath: URL
    
    private init() {
        // 日志文件路径
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appFolder = appSupport.appendingPathComponent("DB-Claude", isDirectory: true)
        
        // 创建目录
        try? FileManager.default.createDirectory(at: appFolder, withIntermediateDirectories: true)
        
        self.logFilePath = appFolder.appendingPathComponent("sql_history.json")
        
        // 加载历史记录
        loadLogs()
    }
    
    // MARK: - 判断是否为 SELECT 语句
    private func isSelectStatement(_ sql: String) -> Bool {
        let trimmed = sql.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        return trimmed.hasPrefix("SELECT") || trimmed.hasPrefix("EXPLAIN")
    }
    
    // MARK: - 记录 SQL
    func log(connectionId: UUID?, connectionName: String, databaseType: String,
             sql: String, duration: TimeInterval, rowCount: Int? = nil,
             success: Bool = true, errorMessage: String? = nil) {
        
        // 打印到控制台（无论成功与否）
        let status = success ? "✓" : "✗"
        let durationStr = String(format: "%.3fs", duration)
        let rowStr = rowCount.map { " (\($0) rows)" } ?? ""
        print("[SQL \(status)] [\(databaseType)] \(durationStr)\(rowStr) | \(sql.prefix(100))\(sql.count > 100 ? "..." : "")")
        
        // 错误的 SQL 不保留到日志
        guard success else { return }
        
        let entry = SQLLogEntry(
            connectionId: connectionId,
            connectionName: connectionName,
            databaseType: databaseType,
            sql: sql,
            duration: duration,
            rowCount: rowCount,
            success: success,
            errorMessage: errorMessage
        )
        
        logs.insert(entry, at: 0)
        
        // 分类型限制日志数量
        trimLogsByType()
        
        // 异步保存
        Task {
            await saveLogs()
        }
    }
    
    // MARK: - 分类型清理日志
    private func trimLogsByType() {
        var selectLogs: [SQLLogEntry] = []
        var otherLogs: [SQLLogEntry] = []
        
        // 分类
        for log in logs {
            if isSelectStatement(log.sql) {
                selectLogs.append(log)
            } else {
                otherLogs.append(log)
            }
        }
        
        // 分别限制数量
        if selectLogs.count > maxSelectCount {
            selectLogs = Array(selectLogs.prefix(maxSelectCount))
        }
        if otherLogs.count > maxOtherCount {
            otherLogs = Array(otherLogs.prefix(maxOtherCount))
        }
        
        // 合并并按时间排序
        logs = (selectLogs + otherLogs).sorted { $0.timestamp > $1.timestamp }
    }
    
    // MARK: - 清除日志
    func clearLogs() {
        logs.removeAll()
        Task {
            await saveLogs()
        }
    }
    
    // MARK: - 按连接筛选
    func logs(for connectionId: UUID?) -> [SQLLogEntry] {
        guard let connectionId = connectionId else { return logs }
        return logs.filter { $0.connectionId == connectionId }
    }
    
    // MARK: - 搜索日志
    func search(_ query: String) -> [SQLLogEntry] {
        guard !query.isEmpty else { return logs }
        let lowercased = query.lowercased()
        return logs.filter { 
            $0.sql.lowercased().contains(lowercased) ||
            $0.connectionName.lowercased().contains(lowercased)
        }
    }
    
    // MARK: - 导出日志
    func exportAsText() -> String {
        var text = "DB-Claude SQL 执行历史\n"
        text += "导出时间: \(Date())\n"
        text += "总记录数: \(logs.count)\n"
        text += String(repeating: "=", count: 80) + "\n\n"
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        
        for log in logs {
            text += "[\(formatter.string(from: log.timestamp))] "
            text += "[\(log.databaseType)] "
            text += "[\(log.connectionName)] "
            text += "\(log.success ? "成功" : "失败") "
            text += String(format: "(%.3fs)", log.duration)
            if let rows = log.rowCount {
                text += " \(rows) 行"
            }
            text += "\n"
            text += log.sql + "\n"
            if let error = log.errorMessage {
                text += "错误: \(error)\n"
            }
            text += "\n"
        }
        
        return text
    }
    
    // MARK: - 持久化
    private func loadLogs() {
        guard FileManager.default.fileExists(atPath: logFilePath.path) else { return }
        
        do {
            let data = try Data(contentsOf: logFilePath)
            var loadedLogs = try JSONDecoder().decode([SQLLogEntry].self, from: data)
            let oldCount = loadedLogs.count
            
            // 过滤掉错误的日志
            loadedLogs = loadedLogs.filter { $0.success }
            
            logs = loadedLogs
            
            // 清理超出限制的日志
            trimLogsByType()
            
            if logs.count < oldCount {
                print("[SQLLogger] 已加载 \(oldCount) 条历史记录，清理后保留 \(logs.count) 条")
                // 保存清理后的日志
                Task {
                    await saveLogs()
                }
            } else {
                print("[SQLLogger] 已加载 \(logs.count) 条历史记录")
            }
        } catch {
            print("[SQLLogger] 加载历史记录失败: \(error)")
        }
    }
    
    private func saveLogs() async {
        do {
            let data = try JSONEncoder().encode(logs)
            try data.write(to: logFilePath)
        } catch {
            print("[SQLLogger] 保存历史记录失败: \(error)")
        }
    }
}

// MARK: - 便捷扩展
extension SQLLogger {
    /// 记录成功的 SQL 执行
    func logSuccess(connectionId: UUID?, connectionName: String, databaseType: String,
                   sql: String, duration: TimeInterval, rowCount: Int? = nil) {
        log(connectionId: connectionId, connectionName: connectionName, databaseType: databaseType,
            sql: sql, duration: duration, rowCount: rowCount, success: true)
    }
    
    /// 记录失败的 SQL 执行
    func logError(connectionId: UUID?, connectionName: String, databaseType: String,
                 sql: String, duration: TimeInterval, error: Error) {
        log(connectionId: connectionId, connectionName: connectionName, databaseType: databaseType,
            sql: sql, duration: duration, success: false, errorMessage: error.localizedDescription)
    }
}
