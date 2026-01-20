import Foundation

/// SQL 格式化和转换工具类
/// 提供 SQL 语句的格式化、DDL 解析、查询转换等功能
enum SQLFormatter {
    
    // MARK: - SQL 格式化
    
    /// 格式化 SQL 语句
    /// - Parameter sql: 原始 SQL 语句
    /// - Returns: 格式化后的 SQL 语句
    static func format(_ sql: String) -> String {
        guard !sql.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return sql }
        
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
        
        return lines.joined(separator: "\n")
    }
    
    // MARK: - DDL 解析
    
    /// 从 DDL 语句解析字段名列表
    /// - Parameter ddl: CREATE TABLE DDL 语句
    /// - Returns: 字段名数组
    static func parseColumnsFromDDL(_ ddl: String) -> [String] {
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
    
    /// 从字段定义行提取字段名
    private static func extractColumnName(from line: String) -> String? {
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
    
    // MARK: - SQL 转换
    
    /// 将 UPDATE/DELETE 语句转换为 SELECT COUNT(*) 语句
    /// 用于预览受影响的行数
    /// - Parameter sql: UPDATE 或 DELETE 语句
    /// - Returns: 对应的 COUNT 查询，如果无法转换则返回 nil
    static func convertToCountQuery(_ sql: String) -> String? {
        let trimmedSQL = sql.trimmingCharacters(in: .whitespacesAndNewlines)
        let upperSQL = trimmedSQL.uppercased()
        
        if upperSQL.hasPrefix("UPDATE ") {
            return convertUpdateToCount(trimmedSQL, upperSQL)
        } else if upperSQL.hasPrefix("DELETE ") {
            return convertDeleteToCount(trimmedSQL, upperSQL)
        }
        
        return nil
    }
    
    /// 将 UPDATE/DELETE 语句转换为预览查询
    /// - Parameter sql: UPDATE 或 DELETE 语句
    /// - Returns: 对应的预览查询，如果无法转换则返回 nil
    static func convertToPreviewQuery(_ sql: String) -> String? {
        let trimmedSQL = sql.trimmingCharacters(in: .whitespacesAndNewlines)
        let upperSQL = trimmedSQL.uppercased()
        
        if upperSQL.hasPrefix("UPDATE ") {
            return convertUpdateToPreview(trimmedSQL, upperSQL)
        } else if upperSQL.hasPrefix("DELETE ") {
            return convertDeleteToPreview(trimmedSQL, upperSQL)
        }
        
        return nil
    }
    
    // MARK: - 私有转换方法
    
    private static func convertUpdateToCount(_ sql: String, _ upperSQL: String) -> String? {
        // UPDATE table SET ... WHERE ... -> SELECT COUNT(*) FROM table WHERE ...
        let nsUpper = upperSQL as NSString
        let nsOriginal = sql as NSString
        
        // 查找 SET 位置
        let setRange = nsUpper.range(of: " SET ")
        guard setRange.location != NSNotFound else { return nil }
        
        // 提取表名（UPDATE 后到 SET 前）
        let tableNameRange = NSRange(location: 7, length: setRange.location - 7)
        let tableName = nsOriginal.substring(with: tableNameRange).trimmingCharacters(in: .whitespaces)
        
        // 查找 WHERE 位置（在 SET 之后）
        let searchStart = setRange.location + setRange.length
        let whereRange = nsUpper.range(of: " WHERE ", options: [], range: NSRange(location: searchStart, length: nsUpper.length - searchStart))
        
        if whereRange.location != NSNotFound {
            // 提取 WHERE 子句（从 WHERE 开始到结尾）
            let whereClause = nsOriginal.substring(from: whereRange.location)
            return "SELECT COUNT(*) AS affected_count FROM \(tableName) \(whereClause)"
        } else {
            // 没有 WHERE 子句，会影响所有行
            return "SELECT COUNT(*) AS affected_count FROM \(tableName)"
        }
    }
    
    private static func convertDeleteToCount(_ sql: String, _ upperSQL: String) -> String? {
        // DELETE FROM table WHERE ... -> SELECT COUNT(*) FROM table WHERE ...
        let nsUpper = upperSQL as NSString
        let nsOriginal = sql as NSString
        
        let fromRange = nsUpper.range(of: "FROM ")
        guard fromRange.location != NSNotFound else { return nil }
        
        let afterFrom = nsOriginal.substring(from: fromRange.location)
        return "SELECT COUNT(*) AS affected_count \(afterFrom)"
    }
    
    private static func convertUpdateToPreview(_ sql: String, _ upperSQL: String) -> String? {
        // UPDATE table SET ... WHERE ... -> SELECT COUNT(1) FROM table WHERE ...
        let nsUpper = upperSQL as NSString
        let nsOriginal = sql as NSString
        
        // 查找 SET 位置
        let setRange = nsUpper.range(of: " SET ")
        guard setRange.location != NSNotFound else { return nil }
        
        // 提取表名（UPDATE 后到 SET 前）
        let tableNameRange = NSRange(location: 7, length: setRange.location - 7)
        let tableName = nsOriginal.substring(with: tableNameRange).trimmingCharacters(in: .whitespaces)
        
        // 查找 WHERE 位置（在 SET 之后）
        let searchStart = setRange.location + setRange.length
        let whereRange = nsUpper.range(of: " WHERE ", options: [], range: NSRange(location: searchStart, length: nsUpper.length - searchStart))
        
        if whereRange.location != NSNotFound {
            // 提取 WHERE 子句（从 WHERE 开始到结尾）
            let whereClause = nsOriginal.substring(from: whereRange.location)
            return "SELECT COUNT(1) FROM \(tableName) \(whereClause)"
        } else {
            return "SELECT COUNT(1) FROM \(tableName)"
        }
    }
    
    private static func convertDeleteToPreview(_ sql: String, _ upperSQL: String) -> String? {
        // DELETE FROM table WHERE ... -> SELECT COUNT(1) FROM table WHERE ...
        let nsUpper = upperSQL as NSString
        let nsOriginal = sql as NSString
        
        let fromRange = nsUpper.range(of: "FROM ")
        guard fromRange.location != NSNotFound else { return nil }
        
        let afterFrom = nsOriginal.substring(from: fromRange.location)
        return "SELECT COUNT(1) \(afterFrom)"
    }
    
    // MARK: - 危险操作检查
    
    /// 检查 SQL 是否包含需要权限的危险操作
    /// - Parameters:
    ///   - sql: SQL 语句
    ///   - allowUpdate: 是否允许 UPDATE
    ///   - allowDelete: 是否允许 DELETE
    ///   - allowAlter: 是否允许 ALTER/DROP/TRUNCATE
    /// - Returns: 如果操作被阻止，返回错误信息；否则返回 nil
    static func checkDangerousOperation(
        _ sql: String,
        allowUpdate: Bool,
        allowDelete: Bool,
        allowAlter: Bool
    ) -> String? {
        let upperSQL = sql.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 检查 UPDATE 操作
        if !allowUpdate && upperSQL.hasPrefix("UPDATE ") {
            return "⚠️ UPDATE 操作被禁止, 请在工具栏中启用「UPDATE」开关后重试。\n此设置用于防止意外修改数据。"
        }
        
        // 检查 DELETE 操作
        if !allowDelete && upperSQL.hasPrefix("DELETE ") {
            return "⚠️ DELETE 操作被禁止, 请在工具栏中启用「DELETE」开关后重试。此设置用于防止意外删除数据。"
        }
        
        // 检查 ALTER/DROP 操作
        if !allowAlter {
            if upperSQL.hasPrefix("ALTER ") {
                return "⚠️ ALTER 操作被禁止, 请在工具栏中启用「ALTER」开关后重试。此设置用于防止意外修改表结构。"
            }
            if upperSQL.hasPrefix("DROP ") {
                return "⚠️ DROP 操作被禁止, 请在工具栏中启用「ALTER」开关后重试。此设置用于防止意外删除表或数据库。"
            }
            if upperSQL.hasPrefix("TRUNCATE ") {
                return "⚠️ TRUNCATE 操作被禁止, 请在工具栏中启用「ALTER」开关后重试。此设置用于防止意外清空表数据。"
            }
        }
        
        return nil
    }
}
