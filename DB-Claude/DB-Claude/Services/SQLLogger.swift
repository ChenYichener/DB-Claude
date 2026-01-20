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
    
    // 配置
    private let maxLogCount: Int = 1000  // 最多保留 1000 条记录
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
    
    // MARK: - 记录 SQL
    func log(connectionId: UUID?, connectionName: String, databaseType: String,
             sql: String, duration: TimeInterval, rowCount: Int? = nil,
             success: Bool = true, errorMessage: String? = nil) {
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
        
        // 限制日志数量
        if logs.count > maxLogCount {
            logs = Array(logs.prefix(maxLogCount))
        }
        
        // 异步保存
        Task {
            await saveLogs()
        }
        
        // 打印到控制台
        let status = success ? "✓" : "✗"
        let durationStr = String(format: "%.3fs", duration)
        let rowStr = rowCount.map { " (\($0) rows)" } ?? ""
        print("[SQL \(status)] [\(databaseType)] \(durationStr)\(rowStr) | \(sql.prefix(100))\(sql.count > 100 ? "..." : "")")
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
            logs = try JSONDecoder().decode([SQLLogEntry].self, from: data)
            print("[SQLLogger] 已加载 \(logs.count) 条历史记录")
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
