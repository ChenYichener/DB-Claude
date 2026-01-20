import Foundation

protocol DatabaseDriver {
    func connect() async throws
    func disconnect() async
    func fetchDatabases() async throws -> [String]
    func fetchTables() async throws -> [String]
    func fetchTablesWithInfo() async throws -> [TableInfo]
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
