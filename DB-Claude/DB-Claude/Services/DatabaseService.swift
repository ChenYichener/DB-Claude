import Foundation

protocol DatabaseDriver {
    func connect() async throws
    func disconnect() async
    func useDatabase(_ database: String) async throws  // 切换当前数据库
    func fetchDatabases() async throws -> [String]
    func fetchTables() async throws -> [String]
    func fetchTablesWithInfo() async throws -> [TableInfo]
    func fetchColumnsWithInfo(for table: String) async throws -> [ColumnInfo]
    func execute(sql: String) async throws -> [[String: String]] // Simple Key-Value result for now
    func getDDL(for table: String) async throws -> String
}

enum DatabaseError: Error {
    case connectionFailed(String)
    case queryFailed(String)
    case notConnected
}

struct DatabaseColumn: Identifiable {
    let id = UUID()
    let name: String
    let type: String
}

/// 表信息（包含 comment）
struct TableInfo: Identifiable, Hashable {
    var id: String { name }
    let name: String
    let comment: String?
    
    init(name: String, comment: String? = nil) {
        self.name = name
        self.comment = comment
    }
}

/// 字段信息（包含 name 和 comment）
struct ColumnInfo: Identifiable, Hashable {
    var id: String { name }
    let name: String
    let comment: String?
    let type: String?
    
    init(name: String, comment: String? = nil, type: String? = nil) {
        self.name = name
        self.comment = comment
        self.type = type
    }
    
    /// 生成格式化的字段显示：`字段名 '别名'`
    /// 如果有 comment 则用 comment 作为别名，否则用字段名本身
    var displayText: String {
        if let comment = comment, !comment.isEmpty {
            return "\(name) '\(comment)'"
        }
        return "\(name) '\(name)'"
    }
}
