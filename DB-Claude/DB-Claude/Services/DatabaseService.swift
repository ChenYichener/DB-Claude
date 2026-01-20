import Foundation

protocol DatabaseDriver {
    func connect() async throws
    func disconnect() async
    func fetchDatabases() async throws -> [String]
    func fetchTables() async throws -> [String]
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
