import Foundation
import SQLite3

class SQLiteDriver: DatabaseDriver {
    private var db: OpaquePointer?
    private let path: String
    private let connectionId: UUID?
    private let connectionName: String
    
    init(path: String, connectionId: UUID? = nil, connectionName: String? = nil) {
        self.path = path
        self.connectionId = connectionId
        self.connectionName = connectionName ?? URL(fileURLWithPath: path).lastPathComponent
    }
    
    deinit {
        // deinit 中无法调用 async 方法，直接关闭
        if db != nil {
            sqlite3_close(db)
            db = nil
        }
    }

    func connect() async throws {
        if sqlite3_open(path, &db) != SQLITE_OK {
            let errorMsg = String(cString: sqlite3_errmsg(db))
            throw DatabaseError.connectionFailed(errorMsg)
        }
    }

    func disconnect() async {
        if db != nil {
            sqlite3_close(db)
            db = nil
        }
    }
    
    func fetchDatabases() async throws -> [String] {
        return ["main"]
    }
    
    func fetchTables() async throws -> [String] {
        let sql = "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%';"
        let results = try await execute(sql: sql)
        return results.compactMap { $0["name"] }
    }
    
    func fetchTablesWithInfo() async throws -> [TableInfo] {
        // SQLite 不支持表级别的 comment，返回空 comment
        let tables = try await fetchTables()
        return tables.map { TableInfo(name: $0, comment: nil) }
    }
    
    func execute(sql: String) async throws -> [[String: String]] {
        let startTime = Date()
        
        do {
            let results = try await executeInternal(sql: sql)
            
            // 记录成功的 SQL
            let duration = Date().timeIntervalSince(startTime)
            let rowCount = results.count > 0 ? results.count - 1 : 0  // 减去元数据行
            await SQLLogger.shared.logSuccess(
                connectionId: connectionId,
                connectionName: connectionName,
                databaseType: "SQLite",
                sql: sql,
                duration: duration,
                rowCount: rowCount
            )
            
            return results
        } catch {
            // 记录失败的 SQL
            let duration = Date().timeIntervalSince(startTime)
            await SQLLogger.shared.logError(
                connectionId: connectionId,
                connectionName: connectionName,
                databaseType: "SQLite",
                sql: sql,
                duration: duration,
                error: error
            )
            throw error
        }
    }
    
    private func executeInternal(sql: String) async throws -> [[String: String]] {
        guard let db = db else {
            throw DatabaseError.notConnected
        }
        
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) != SQLITE_OK {
            let errorMsg = String(cString: sqlite3_errmsg(db))
            throw DatabaseError.queryFailed(errorMsg)
        }
        
        defer {
            sqlite3_finalize(statement)
        }
        
        var results: [[String: String]] = []
        let columnCount = sqlite3_column_count(statement)
        
        // 获取列名顺序（按 DDL 顺序）
        var columnNames: [String] = []
        for i in 0..<columnCount {
            let columnName = String(cString: sqlite3_column_name(statement, i))
            columnNames.append(columnName)
        }
        
        // 在结果中添加一个特殊的元数据行，存储列顺序
        if !columnNames.isEmpty {
            var metaRow: [String: String] = [:]
            metaRow["__columns__"] = columnNames.joined(separator: ",")
            results.append(metaRow)
        }
        
        while sqlite3_step(statement) == SQLITE_ROW {
            var row: [String: String] = [:]
            for i in 0..<columnCount {
                let columnName = columnNames[Int(i)]
                let columnType = sqlite3_column_type(statement, i)
                
                // 根据列类型获取值，支持所有 SQLite 数据类型
                switch columnType {
                case SQLITE_NULL:
                    row[columnName] = nil  // 真正的 NULL
                case SQLITE_INTEGER:
                    let value = sqlite3_column_int64(statement, i)
                    // 检查是否可能是 Unix 时间戳（日期时间）
                    // Unix 时间戳通常在 1970-2100 年范围内：0 ~ 4102444800
                    if value > 946684800 && value < 4102444800 {
                        // 可能是时间戳，尝试转换为日期字符串
                        let date = Date(timeIntervalSince1970: TimeInterval(value))
                        let formatter = ISO8601DateFormatter()
                        formatter.formatOptions = [.withFullDate, .withTime, .withSpaceBetweenDateAndTime, .withColonSeparatorInTime]
                        row[columnName] = formatter.string(from: date)
                    } else {
                        row[columnName] = String(value)
                    }
                case SQLITE_FLOAT:
                    let value = sqlite3_column_double(statement, i)
                    // 检查是否可能是 Julian 日期（SQLite 日期存储格式之一）
                    // Julian 日期通常在 2440000 ~ 2500000 范围内（1968-2132年）
                    if value > 2440000 && value < 2500000 {
                        // 是 Julian 日期，转换为标准日期
                        let unixTime = (value - 2440587.5) * 86400.0
                        let date = Date(timeIntervalSince1970: unixTime)
                        let formatter = ISO8601DateFormatter()
                        formatter.formatOptions = [.withFullDate, .withTime, .withSpaceBetweenDateAndTime, .withColonSeparatorInTime]
                        row[columnName] = formatter.string(from: date)
                    } else {
                        row[columnName] = String(value)
                    }
                case SQLITE_BLOB:
                    let bytes = sqlite3_column_bytes(statement, i)
                    row[columnName] = "<BLOB \(bytes) bytes>"
                case SQLITE_TEXT:
                    fallthrough
                default:
                    // 对于 TEXT 和其他类型，尝试获取文本值
                    if let columnText = sqlite3_column_text(statement, i) {
                        row[columnName] = String(cString: columnText)
                    } else {
                        row[columnName] = nil
                    }
                }
            }
            results.append(row)
        }
        
        return results
    }
    
    func getDDL(for table: String) async throws -> String {
        let sql = "SELECT sql FROM sqlite_master WHERE type='table' AND name = '\(table)';"
        let results = try await execute(sql: sql)
        if let ddl = results.first?["sql"] {
            return ddl
        }
        throw DatabaseError.queryFailed("Table not found or no DDL available")
    }
}
