import Foundation

/// SQL 语法验证器
struct SQLValidator {
    
    /// 验证结果
    struct ValidationResult {
        let isValid: Bool
        let errors: [SQLError]
        let warnings: [SQLWarning]
    }
    
    /// SQL 错误
    struct SQLError: Identifiable {
        let id = UUID()
        let message: String
        let suggestion: String?
        let position: Int?  // 错误位置（字符索引）
    }
    
    /// SQL 警告
    struct SQLWarning: Identifiable {
        let id = UUID()
        let message: String
        let suggestion: String?
    }
    
    /// 验证 SQL 语句
    static func validate(_ sql: String) -> ValidationResult {
        var errors: [SQLError] = []
        var warnings: [SQLWarning] = []
        
        let trimmedSQL = sql.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSQL.isEmpty else {
            return ValidationResult(isValid: true, errors: [], warnings: [])
        }
        
        let upperSQL = trimmedSQL.uppercased()
        
        // 检查括号匹配
        if let error = checkParenthesesBalance(trimmedSQL) {
            errors.append(error)
        }
        
        // 检查引号匹配
        if let error = checkQuotesBalance(trimmedSQL) {
            errors.append(error)
        }
        
        // 检查 SELECT 语句
        if upperSQL.hasPrefix("SELECT") {
            errors.append(contentsOf: validateSelectStatement(trimmedSQL, upperSQL))
        }
        
        // 检查 UPDATE 语句
        if upperSQL.hasPrefix("UPDATE") {
            errors.append(contentsOf: validateUpdateStatement(trimmedSQL, upperSQL))
        }
        
        // 检查 DELETE 语句
        if upperSQL.hasPrefix("DELETE") {
            errors.append(contentsOf: validateDeleteStatement(trimmedSQL, upperSQL))
        }
        
        // 检查 INSERT 语句
        if upperSQL.hasPrefix("INSERT") {
            errors.append(contentsOf: validateInsertStatement(trimmedSQL, upperSQL))
        }
        
        // 检查常见错误模式
        errors.append(contentsOf: checkCommonMistakes(trimmedSQL, upperSQL))
        
        // 添加警告
        warnings.append(contentsOf: checkWarnings(trimmedSQL, upperSQL))
        
        return ValidationResult(
            isValid: errors.isEmpty,
            errors: errors,
            warnings: warnings
        )
    }
    
    // MARK: - 括号检查
    private static func checkParenthesesBalance(_ sql: String) -> SQLError? {
        var count = 0
        var inString = false
        var stringChar: Character = "\""
        
        for char in sql {
            if !inString {
                if char == "'" || char == "\"" {
                    inString = true
                    stringChar = char
                } else if char == "(" {
                    count += 1
                } else if char == ")" {
                    count -= 1
                    if count < 0 {
                        return SQLError(
                            message: "括号不匹配：多余的右括号 ')'",
                            suggestion: "检查括号是否正确配对",
                            position: nil
                        )
                    }
                }
            } else {
                if char == stringChar {
                    inString = false
                }
            }
        }
        
        if count > 0 {
            return SQLError(
                message: "括号不匹配：缺少 \(count) 个右括号 ')'",
                suggestion: "在语句末尾添加对应的右括号",
                position: nil
            )
        }
        
        return nil
    }
    
    // MARK: - 引号检查
    private static func checkQuotesBalance(_ sql: String) -> SQLError? {
        var singleQuoteCount = 0
        var doubleQuoteCount = 0
        var prevChar: Character = " "
        
        for char in sql {
            if char == "'" && prevChar != "\\" {
                singleQuoteCount += 1
            } else if char == "\"" && prevChar != "\\" {
                doubleQuoteCount += 1
            }
            prevChar = char
        }
        
        if singleQuoteCount % 2 != 0 {
            return SQLError(
                message: "引号不匹配：单引号 ' 未闭合",
                suggestion: "检查字符串是否正确用单引号包裹",
                position: nil
            )
        }
        
        if doubleQuoteCount % 2 != 0 {
            return SQLError(
                message: "引号不匹配：双引号 \" 未闭合",
                suggestion: "检查标识符是否正确用双引号包裹",
                position: nil
            )
        }
        
        return nil
    }
    
    // MARK: - SELECT 语句验证
    private static func validateSelectStatement(_ sql: String, _ upperSQL: String) -> [SQLError] {
        var errors: [SQLError] = []
        
        // 检查是否有 FROM（除了 SELECT 1 这种情况）
        if !upperSQL.contains("FROM") {
            // 检查是否是简单的表达式查询（如 SELECT 1, SELECT NOW()）
            let afterSelect = upperSQL.replacingOccurrences(of: "SELECT", with: "").trimmingCharacters(in: .whitespaces)
            if !afterSelect.isEmpty && 
               !afterSelect.hasPrefix("1") && 
               !afterSelect.hasPrefix("NOW") &&
               !afterSelect.hasPrefix("CURRENT") &&
               !afterSelect.hasPrefix("VERSION") &&
               !afterSelect.contains("(") {
                errors.append(SQLError(
                    message: "SELECT 语句可能缺少 FROM 子句",
                    suggestion: "添加 FROM 表名 来指定数据来源",
                    position: nil
                ))
            }
        }
        
        // 检查 FROM 后直接跟比较运算符的错误（如 SELECT * FROM table = 1）
        let fromPattern = "FROM\\s+\\w+\\s*[=<>!]"
        if let regex = try? NSRegularExpression(pattern: fromPattern, options: .caseInsensitive) {
            let range = NSRange(sql.startIndex..., in: sql)
            if regex.firstMatch(in: sql, range: range) != nil && !upperSQL.contains("WHERE") {
                errors.append(SQLError(
                    message: "语法错误：FROM 后直接使用了比较运算符",
                    suggestion: "在条件前添加 WHERE 关键字，如：SELECT * FROM table WHERE column = 1",
                    position: nil
                ))
            }
        }
        
        return errors
    }
    
    // MARK: - UPDATE 语句验证
    private static func validateUpdateStatement(_ sql: String, _ upperSQL: String) -> [SQLError] {
        var errors: [SQLError] = []
        
        // 检查是否有 SET
        if !upperSQL.contains("SET") {
            errors.append(SQLError(
                message: "UPDATE 语句缺少 SET 子句",
                suggestion: "使用 UPDATE table SET column = value 格式",
                position: nil
            ))
        }
        
        // 警告：没有 WHERE 的 UPDATE 很危险
        if !upperSQL.contains("WHERE") {
            errors.append(SQLError(
                message: "⚠️ UPDATE 语句没有 WHERE 条件",
                suggestion: "这将更新表中的所有行！请添加 WHERE 条件限制更新范围",
                position: nil
            ))
        }
        
        return errors
    }
    
    // MARK: - DELETE 语句验证
    private static func validateDeleteStatement(_ sql: String, _ upperSQL: String) -> [SQLError] {
        var errors: [SQLError] = []
        
        // 检查是否有 FROM
        if !upperSQL.contains("FROM") {
            errors.append(SQLError(
                message: "DELETE 语句缺少 FROM 子句",
                suggestion: "使用 DELETE FROM table WHERE ... 格式",
                position: nil
            ))
        }
        
        // 警告：没有 WHERE 的 DELETE 很危险
        if !upperSQL.contains("WHERE") {
            errors.append(SQLError(
                message: "⚠️ DELETE 语句没有 WHERE 条件",
                suggestion: "这将删除表中的所有行！请添加 WHERE 条件限制删除范围",
                position: nil
            ))
        }
        
        return errors
    }
    
    // MARK: - INSERT 语句验证
    private static func validateInsertStatement(_ sql: String, _ upperSQL: String) -> [SQLError] {
        var errors: [SQLError] = []
        
        // 检查是否有 INTO
        if !upperSQL.contains("INTO") {
            errors.append(SQLError(
                message: "INSERT 语句缺少 INTO 关键字",
                suggestion: "使用 INSERT INTO table (columns) VALUES (...) 格式",
                position: nil
            ))
        }
        
        // 检查是否有 VALUES 或 SELECT
        if !upperSQL.contains("VALUES") && !upperSQL.contains("SELECT") {
            errors.append(SQLError(
                message: "INSERT 语句缺少 VALUES 或 SELECT",
                suggestion: "使用 VALUES (...) 或 SELECT 提供要插入的数据",
                position: nil
            ))
        }
        
        return errors
    }
    
    // MARK: - 常见错误检查
    private static func checkCommonMistakes(_ sql: String, _ upperSQL: String) -> [SQLError] {
        var errors: [SQLError] = []
        
        // 检查 == 错误（应该用 =）
        if sql.contains("==") {
            errors.append(SQLError(
                message: "SQL 中应使用单个等号 = 进行比较，而不是 ==",
                suggestion: "将 == 替换为 =",
                position: nil
            ))
        }
        
        // 检查 != 可以用，但建议使用 <>
        // 这个不报错，只是 MySQL 标准
        
        // 检查 && 和 || 错误
        if sql.contains("&&") {
            errors.append(SQLError(
                message: "SQL 中应使用 AND 而不是 &&",
                suggestion: "将 && 替换为 AND",
                position: nil
            ))
        }
        
        if sql.contains("||") && !upperSQL.contains("CONCAT") {
            // || 在 MySQL 中默认是 OR，但在标准 SQL 中是字符串连接
            // 这里只提示一下
        }
        
        // 检查 LIMIT 后没有数字
        let limitPattern = "LIMIT\\s*$"
        if let regex = try? NSRegularExpression(pattern: limitPattern, options: .caseInsensitive) {
            let range = NSRange(sql.startIndex..., in: sql)
            if regex.firstMatch(in: sql, range: range) != nil {
                errors.append(SQLError(
                    message: "LIMIT 后缺少数量",
                    suggestion: "指定要限制的行数，如 LIMIT 10",
                    position: nil
                ))
            }
        }
        
        // 检查 ORDER BY 后没有字段
        let orderByPattern = "ORDER\\s+BY\\s*$"
        if let regex = try? NSRegularExpression(pattern: orderByPattern, options: .caseInsensitive) {
            let range = NSRange(sql.startIndex..., in: sql)
            if regex.firstMatch(in: sql, range: range) != nil {
                errors.append(SQLError(
                    message: "ORDER BY 后缺少排序字段",
                    suggestion: "指定排序字段，如 ORDER BY id DESC",
                    position: nil
                ))
            }
        }
        
        // 检查 GROUP BY 后没有字段
        let groupByPattern = "GROUP\\s+BY\\s*$"
        if let regex = try? NSRegularExpression(pattern: groupByPattern, options: .caseInsensitive) {
            let range = NSRange(sql.startIndex..., in: sql)
            if regex.firstMatch(in: sql, range: range) != nil {
                errors.append(SQLError(
                    message: "GROUP BY 后缺少分组字段",
                    suggestion: "指定分组字段，如 GROUP BY category",
                    position: nil
                ))
            }
        }
        
        // 检查 WHERE 后没有条件
        let wherePattern = "WHERE\\s*$"
        if let regex = try? NSRegularExpression(pattern: wherePattern, options: .caseInsensitive) {
            let range = NSRange(sql.startIndex..., in: sql)
            if regex.firstMatch(in: sql, range: range) != nil {
                errors.append(SQLError(
                    message: "WHERE 后缺少条件",
                    suggestion: "添加过滤条件，如 WHERE id = 1",
                    position: nil
                ))
            }
        }
        
        return errors
    }
    
    // MARK: - 警告检查
    private static func checkWarnings(_ sql: String, _ upperSQL: String) -> [SQLWarning] {
        var warnings: [SQLWarning] = []
        
        // SELECT * 警告
        if upperSQL.contains("SELECT *") || upperSQL.contains("SELECT  *") {
            warnings.append(SQLWarning(
                message: "使用 SELECT * 可能会影响性能",
                suggestion: "建议明确指定需要的列名"
            ))
        }
        
        // 大的 LIMIT 警告
        let limitPattern = "LIMIT\\s+(\\d+)"
        if let regex = try? NSRegularExpression(pattern: limitPattern, options: .caseInsensitive) {
            let range = NSRange(sql.startIndex..., in: sql)
            if let match = regex.firstMatch(in: sql, range: range) {
                let numberRange = Range(match.range(at: 1), in: sql)!
                if let limit = Int(sql[numberRange]), limit > 10000 {
                    warnings.append(SQLWarning(
                        message: "LIMIT \(limit) 可能返回大量数据",
                        suggestion: "考虑减少 LIMIT 值或添加分页"
                    ))
                }
            }
        }
        
        return warnings
    }
}
