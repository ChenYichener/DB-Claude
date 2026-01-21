import Foundation



#if canImport(MySQLNIO)
import MySQLNIO
import NIOCore
import NIOPosix

class RealMySQLDriver: DatabaseDriver {
    let connection: Connection
    var client: MySQLConnection?
    let eventLoopGroup: MultiThreadedEventLoopGroup
    
    // 重连配置
    private var lastActivityTime: Date = Date()
    private let connectionTimeout: TimeInterval = 300  // 5 分钟无活动则检查连接
    private var isReconnecting: Bool = false
    
    init(connection: Connection) {
        self.connection = connection
        self.eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
    }
    
    deinit {
        // 同步关闭连接，避免 MySQLNIO 的断言失败
        if let client = client, !client.isClosed {
            do {
                try client.close().wait()
            } catch {
                print("[MySQL] deinit 关闭连接失败: \(error)")
            }
        }
        client = nil
        try? eventLoopGroup.syncShutdownGracefully()
    }

    func connect() async throws {
        guard let host = connection.host, !host.isEmpty,
              let username = connection.username else {
            throw DatabaseError.connectionFailed("Missing configuration")
        }

        let port = connection.port ?? 3306
        // 从 Keychain 获取密码
        let password = connection.getSecurePassword() ?? ""
        // 如果未指定数据库，使用 information_schema（所有 MySQL 实例都有此库）
        let userDatabase = connection.databaseName ?? ""
        let database = userDatabase.isEmpty ? "information_schema" : userDatabase

        // 诊断日志：输出连接参数
        print("[MySQL] 正在连接...")
        print("[MySQL] 主机: \(host)")
        print("[MySQL] 端口: \(port)")
        print("[MySQL] 用户: \(username)")
        print("[MySQL] 密码: \(password.isEmpty ? "(空)" : "(已设置，来自 Keychain)")")
        print("[MySQL] 数据库: \(userDatabase.isEmpty ? "(未指定，使用 information_schema)" : userDatabase)")

        // Basic configuration
        let socketAddress = try SocketAddress.makeAddressResolvingHost(host, port: port)

        // Attempt connection
        // 使用 nil 禁用 TLS（适合本地开发环境）
        // 生产环境应该使用 .makeClientConfiguration() 并配置正确的证书
        client = try await MySQLConnection.connect(
            to: socketAddress,
            username: username,
            database: database,
            password: password,
            tlsConfiguration: nil,
            on: eventLoopGroup.next()
        ).get()

        lastActivityTime = Date()
        print("[MySQL] 连接成功！")
    }

    func disconnect() async {
        if let client = client {
            try? await client.close().get()
            self.client = nil
        }
    }
    
    /// 当前使用的数据库名（用户选择的，非连接配置中的）
    private var currentDatabase: String = ""
    
    func useDatabase(_ database: String) async throws {
        guard !database.isEmpty else { return }
        guard let client = self.client else { throw DatabaseError.notConnected }
        
        do {
            // 使用 simpleQuery 执行 USE 语句（不返回结果集）
            _ = try await client.simpleQuery("USE `\(database)`").get()
            self.currentDatabase = database
            print("[MySQL] 已切换到数据库: \(database)")
        } catch {
            print("[MySQL] 切换数据库失败: \(error)")
            // 即使 USE 失败，也设置 currentDatabase，让后续查询使用完整表名
            self.currentDatabase = database
        }
    }
    
    /// 确保连接可用，如果断开则自动重连
    private func ensureConnected() async throws {
        // 如果没有连接，直接建立连接
        guard let client = client else {
            print("[MySQL] 连接不存在，正在建立新连接...")
            try await connect()
            return
        }
        
        // 检查连接是否已关闭
        if client.isClosed {
            print("[MySQL] 连接已断开，正在重新连接...")
            self.client = nil
            try await connect()
            return
        }
        
        // 如果距离上次活动超过超时时间，进行连接测试
        let timeSinceLastActivity = Date().timeIntervalSince(lastActivityTime)
        if timeSinceLastActivity > connectionTimeout {
            print("[MySQL] 连接空闲超过 \(Int(timeSinceLastActivity)) 秒，正在验证连接...")
            
            do {
                // 发送简单查询测试连接
                _ = try await client.query("SELECT 1").get()
                lastActivityTime = Date()
                print("[MySQL] 连接验证成功")
            } catch {
                print("[MySQL] 连接验证失败: \(error.localizedDescription)，正在重新连接...")
                self.client = nil
                try await connect()
            }
        }
    }
    
    /// 带自动重连的查询执行
    private func executeWithReconnect<T>(_ operation: () async throws -> T) async throws -> T {
        // 首先确保连接可用
        try await ensureConnected()
        
        do {
            let result = try await operation()
            lastActivityTime = Date()
            return result
        } catch {
            // 检查是否是连接错误
            let errorString = String(describing: error).lowercased()
            if errorString.contains("closed") || 
               errorString.contains("connection") ||
               errorString.contains("eof") ||
               errorString.contains("reset") {
                print("[MySQL] 查询失败（连接错误），正在重试: \(error.localizedDescription)")
                
                // 尝试重新连接
                self.client = nil
                try await connect()
                
                // 重试操作
                let result = try await operation()
                lastActivityTime = Date()
                return result
            }
            
            // 非连接错误，直接抛出
            throw error
        }
    }
    
    func fetchDatabases() async throws -> [String] {
        return try await executeWithReconnect {
            guard let client = self.client else { throw DatabaseError.notConnected }

            print("[MySQL] 正在查询数据库列表...")

            // 执行 SHOW DATABASES 查询
            let rows = try await client.query("SHOW DATABASES").get()

            var databases: [String] = []
            for row in rows {
                // MySQL 的 SHOW DATABASES 返回的第一列是数据库名
                if let dbName = row.columnDefinitions.first?.name,
                   let value = row.column(dbName)?.string {
                    // 过滤掉系统数据库（可选）
                    if !["information_schema", "mysql", "performance_schema", "sys"].contains(value) {
                        databases.append(value)
                    }
                }
            }

            print("[MySQL] 找到 \(databases.count) 个数据库")
            return databases
        }
    }
    
    func fetchTables() async throws -> [String] {
        return try await executeWithReconnect {
            guard let client = self.client else { return [] }
            // Simple query
            let rows = try await client.query("SHOW TABLES").get()
            return rows.compactMap { row in
                // Use the first column definition to get the name
                guard let firstColName = row.columnDefinitions.first?.name else { return nil }
                return row.column(firstColName)?.string
            }
        }
    }
    
    func fetchTablesWithInfo() async throws -> [TableInfo] {
        return try await executeWithReconnect {
            guard let client = self.client else { return [] }
            
            // 使用当前选择的数据库，如果没有则使用连接配置中的
            let dbName = self.currentDatabase.isEmpty ? (self.connection.databaseName ?? "") : self.currentDatabase
            guard !dbName.isEmpty else {
                // 如果没有指定数据库，退回到只获取表名
                let rows = try await client.query("SHOW TABLES").get()
                return rows.compactMap { row in
                    guard let firstColName = row.columnDefinitions.first?.name else { return nil }
                    guard let tableName = row.column(firstColName)?.string else { return nil }
                    return TableInfo(name: tableName, comment: nil)
                }
            }
            
            // 从 information_schema 查询表名和 comment
            let sql = """
                SELECT TABLE_NAME, TABLE_COMMENT 
                FROM information_schema.TABLES 
                WHERE TABLE_SCHEMA = '\(dbName)' 
                ORDER BY TABLE_NAME
                """
            let rows = try await client.query(sql).get()
            
            return rows.compactMap { row in
                guard let tableName = row.column("TABLE_NAME")?.string else { return nil }
                let comment = row.column("TABLE_COMMENT")?.string
                // 过滤掉空 comment
                let validComment = (comment?.isEmpty == true) ? nil : comment
                return TableInfo(name: tableName, comment: validComment)
            }
        }
    }
    
    func fetchColumnsWithInfo(for table: String) async throws -> [ColumnInfo] {
        return try await executeWithReconnect {
            guard let client = self.client else { return [] }
            
            // 使用当前选择的数据库，如果没有则使用连接配置中的
            let dbName = self.currentDatabase.isEmpty ? (self.connection.databaseName ?? "") : self.currentDatabase
            guard !dbName.isEmpty else { return [] }
            
            // 从 information_schema 查询字段名和 comment
            let sql = """
                SELECT COLUMN_NAME, COLUMN_COMMENT, COLUMN_TYPE
                FROM information_schema.COLUMNS 
                WHERE TABLE_SCHEMA = '\(dbName)' AND TABLE_NAME = '\(table)'
                ORDER BY ORDINAL_POSITION
                """
            let rows = try await client.query(sql).get()
            
            return rows.compactMap { row in
                guard let columnName = row.column("COLUMN_NAME")?.string else { return nil }
                let comment = row.column("COLUMN_COMMENT")?.string
                let columnType = row.column("COLUMN_TYPE")?.string
                // 过滤掉空 comment
                let validComment = (comment?.isEmpty == true) ? nil : comment
                return ColumnInfo(name: columnName, comment: validComment, type: columnType)
            }
        }
    }
    
    func execute(sql: String) async throws -> [[String: String]] {
        let startTime = Date()
        
        do {
            let result = try await executeWithReconnect {
                guard let client = self.client else { throw DatabaseError.notConnected }
                
                let rows = try await client.query(sql).get()
                
                var result: [[String: String]] = []
                
                // 获取列名顺序（按 DDL 顺序）
                if let firstRow = rows.first {
                    let columnNames = firstRow.columnDefinitions.map { $0.name }
                    // 添加元数据行，存储列顺序
                    var metaRow: [String: String] = [:]
                    metaRow["__columns__"] = columnNames.joined(separator: ",")
                    result.append(metaRow)
                }
                
                // 转换行数据
                for row in rows {
                    var rowDict: [String: String] = [:]
                    for column in row.columnDefinitions {
                        let columnName = column.name
                        let columnType = column.columnType
                        
                        // 尝试多种方式获取值
                        if let mysqlData = row.column(columnName) {
                            // 根据列类型选择处理方式
                            let value = self.extractMySQLValue(mysqlData: mysqlData, columnType: columnType)
                            rowDict[columnName] = value
                        } else {
                            rowDict[columnName] = nil
                        }
                    }
                    result.append(rowDict)
                }
                return result
            }
            
            // 记录成功的 SQL
            let duration = Date().timeIntervalSince(startTime)
            let rowCount = result.count > 0 ? result.count - 1 : 0  // 减去元数据行
            await SQLLogger.shared.logSuccess(
                connectionId: connection.id,
                connectionName: connection.name,
                databaseType: "MySQL",
                sql: sql,
                duration: duration,
                rowCount: rowCount
            )
            
            return result
        } catch {
            // 记录失败的 SQL
            let duration = Date().timeIntervalSince(startTime)
            await SQLLogger.shared.logError(
                connectionId: connection.id,
                connectionName: connection.name,
                databaseType: "MySQL",
                sql: sql,
                duration: duration,
                error: error
            )
            throw error
        }
    }
    
    /// 从 MySQLData 提取值
    private func extractMySQLValue(mysqlData: MySQLData, columnType: MySQLProtocol.DataType) -> String? {
        // 首先检查是否为日期/时间类型
        let isDateTimeType = [
            MySQLProtocol.DataType.date,
            MySQLProtocol.DataType.datetime,
            MySQLProtocol.DataType.timestamp,
            MySQLProtocol.DataType.time,
            MySQLProtocol.DataType.year
        ].contains(columnType)
        
        // 对于日期时间类型，优先尝试从 buffer 解析
        if isDateTimeType {
            if var buffer = mysqlData.buffer {
                let bytes = buffer.readableBytes
                if bytes > 0 {
                    if let data = buffer.readBytes(length: bytes) {
                        // 尝试解析二进制日期格式
                        if let parsed = parseMySQLBinaryDateTime(data, columnType: columnType) {
                            return parsed
                        }
                        // 如果解析失败，尝试 UTF-8 字符串
                        if let str = String(bytes: data, encoding: .utf8), !str.isEmpty {
                            // 过滤零日期
                            if str == "0000-00-00" || str == "0000-00-00 00:00:00" {
                                return nil
                            }
                            return str
                        }
                    }
                }
            }
            // 尝试字符串方式
            if let stringValue = mysqlData.string {
                if stringValue == "0000-00-00" || stringValue == "0000-00-00 00:00:00" {
                    return nil
                }
                return stringValue
            }
            return nil
        }
        
        // 非日期类型的正常处理
        // 方法1: 直接获取字符串
        if let stringValue = mysqlData.string {
            return stringValue
        }
        // 方法2: 整数类型
        if let intValue = mysqlData.int {
            return String(intValue)
        }
        // 方法3: 浮点类型
        if let doubleValue = mysqlData.double {
            return String(doubleValue)
        }
        // 方法4: 布尔类型
        if let boolValue = mysqlData.bool {
            return boolValue ? "1" : "0"
        }
        // 方法5: 从 buffer 读取
        if var buffer = mysqlData.buffer {
            let bytes = buffer.readableBytes
            if bytes > 0 {
                if let str = buffer.readString(length: bytes) {
                    return str
                }
                buffer.moveReaderIndex(to: 0)
                if let data = buffer.readBytes(length: bytes) {
                    if let str = String(bytes: data, encoding: .utf8) {
                        return str
                    }
                    return "<BINARY \(bytes) bytes>"
                }
            }
        }
        return nil
    }
    
    /// 解析 MySQL 二进制日期/时间格式
    private func parseMySQLBinaryDateTime(_ bytes: [UInt8], columnType: MySQLProtocol.DataType) -> String? {
        guard !bytes.isEmpty else { return nil }
        
        switch columnType {
        case .date:
            // DATE: 4 bytes - year(2) month(1) day(1)
            guard bytes.count >= 4 else { return nil }
            let year = Int(bytes[0]) | (Int(bytes[1]) << 8)
            let month = Int(bytes[2])
            let day = Int(bytes[3])
            if year == 0 && month == 0 && day == 0 { return nil }
            return String(format: "%04d-%02d-%02d", year, month, day)
            
        case .datetime, .timestamp:
            // DATETIME/TIMESTAMP: 
            // 0 bytes = zero value
            // 4 bytes = date only
            // 7 bytes = date + time
            // 11 bytes = date + time + microseconds
            if bytes.count == 0 { return nil }
            
            guard bytes.count >= 4 else { return nil }
            let year = Int(bytes[0]) | (Int(bytes[1]) << 8)
            let month = Int(bytes[2])
            let day = Int(bytes[3])
            
            if year == 0 && month == 0 && day == 0 { return nil }
            
            if bytes.count >= 7 {
                let hour = Int(bytes[4])
                let minute = Int(bytes[5])
                let second = Int(bytes[6])
                
                if bytes.count >= 11 {
                    // 带微秒
                    let micro = Int(bytes[7]) | (Int(bytes[8]) << 8) | (Int(bytes[9]) << 16) | (Int(bytes[10]) << 24)
                    return String(format: "%04d-%02d-%02d %02d:%02d:%02d.%06d", year, month, day, hour, minute, second, micro)
                }
                return String(format: "%04d-%02d-%02d %02d:%02d:%02d", year, month, day, hour, minute, second)
            }
            return String(format: "%04d-%02d-%02d 00:00:00", year, month, day)
            
        case .time:
            // TIME: 
            // 0 bytes = zero
            // 8 bytes = negative flag(1) + days(4) + hour(1) + minute(1) + second(1)
            // 12 bytes = above + microseconds(4)
            if bytes.count == 0 { return "00:00:00" }
            guard bytes.count >= 8 else { return nil }
            
            let isNegative = bytes[0] == 1
            let days = Int(bytes[1]) | (Int(bytes[2]) << 8) | (Int(bytes[3]) << 16) | (Int(bytes[4]) << 24)
            let hours = Int(bytes[5]) + days * 24
            let minutes = Int(bytes[6])
            let seconds = Int(bytes[7])
            
            let sign = isNegative ? "-" : ""
            return String(format: "%@%02d:%02d:%02d", sign, hours, minutes, seconds)
            
        case .year:
            // YEAR: 1 byte
            guard bytes.count >= 1 else { return nil }
            let year = 1900 + Int(bytes[0])
            return String(year)
            
        default:
            return nil
        }
    }
    
    func getDDL(for table: String) async throws -> String {
        return try await executeWithReconnect {
            guard let client = self.client else { throw DatabaseError.notConnected }
            let rows = try await client.query("SHOW CREATE TABLE \(table)").get()
            
            // "Create Table" is usually the 2nd column
            for row in rows {
                 for col in row.columnDefinitions {
                     if col.name.lowercased().contains("create table") {
                         return row.column(col.name)?.string ?? ""
                     }
                 }
            }
            
            return "DDL not found"
        }
    }
}
#else
class RealMySQLDriver: DatabaseDriver {
    let connection: Connection
    
    init(connection: Connection) {
        self.connection = connection
    }
    
    func connect() async throws {
        throw DatabaseError.connectionFailed("MySQLNIO module not found. Please ensure 'mysql-nio' is added to your Target's 'Frameworks, Libraries, and Embedded Content'.")
    }
    
    func disconnect() {}
    func useDatabase(_ database: String) async throws {}
    func fetchDatabases() async throws -> [String] { return [] }
    func fetchTables() async throws -> [String] { return [] }
    func fetchTablesWithInfo() async throws -> [TableInfo] { return [] }
    func fetchColumnsWithInfo(for table: String) async throws -> [ColumnInfo] { return [] }
    func execute(sql: String) async throws -> [[String: String]] { return [] }
    func getDDL(for table: String) async throws -> String { return "" }
}
#endif
