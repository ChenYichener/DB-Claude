import SwiftUI

/// SQL 语法高亮器 - 将 SQL 文本转换为带颜色的 AttributedString
struct SQLSyntaxHighlighter {

    // SQL 关键字列表
    private static let keywords: Set<String> = [
        "SELECT", "FROM", "WHERE", "AND", "OR", "NOT", "IN", "BETWEEN", "LIKE",
        "JOIN", "LEFT", "RIGHT", "INNER", "OUTER", "CROSS", "ON", "USING",
        "INSERT", "INTO", "VALUES", "UPDATE", "SET", "DELETE",
        "CREATE", "TABLE", "ALTER", "DROP", "INDEX",
        "GROUP BY", "ORDER BY", "HAVING", "LIMIT", "OFFSET",
        "UNION", "EXCEPT", "INTERSECT", "DISTINCT", "ALL",
        "AS", "ASC", "DESC", "NULL", "IS", "EXISTS",
        "CASE", "WHEN", "THEN", "ELSE", "END"
    ]

    // SQL 函数列表
    private static let functions: Set<String> = [
        "COUNT", "SUM", "AVG", "MIN", "MAX",
        "UPPER", "LOWER", "LENGTH", "TRIM", "SUBSTR",
        "CONCAT", "REPLACE", "COALESCE", "NULLIF",
        "CAST", "CONVERT", "DATE", "TIME", "DATETIME",
        "NOW", "CURRENT_TIMESTAMP", "CURRENT_DATE"
    ]

    /// 高亮 SQL 文本（默认 14pt 字体）
    static func highlight(_ sql: String) -> AttributedString {
        return highlight(sql, fontSize: 14)
    }
    
    /// 高亮 SQL 文本（自定义字体大小）
    static func highlight(_ sql: String, fontSize: CGFloat) -> AttributedString {
        var attributed = AttributedString(sql)

        // 基础样式
        attributed.font = .monospacedSystemFont(ofSize: fontSize, weight: .regular)
        attributed.foregroundColor = AppColors.primaryText

        let upperSQL = sql.uppercased()

        // 1. 高亮注释（-- 和 /* */）
        highlightComments(in: sql, attributed: &attributed, fontSize: fontSize)

        // 2. 高亮字符串（单引号）
        highlightStrings(in: sql, attributed: &attributed)

        // 3. 高亮数字
        highlightNumbers(in: sql, attributed: &attributed)

        // 4. 高亮关键字
        for keyword in keywords {
            highlightPattern(keyword, in: upperSQL, originalText: sql, attributed: &attributed, color: AppColors.sqlKeyword, isBold: true, fontSize: fontSize)
        }

        // 5. 高亮函数
        for function in functions {
            highlightPattern(function, in: upperSQL, originalText: sql, attributed: &attributed, color: AppColors.sqlFunction, isBold: false, fontSize: fontSize)
        }

        // 6. 高亮操作符
        highlightOperators(in: sql, attributed: &attributed)

        return attributed
    }

    // MARK: - 私有辅助方法

    /// 高亮注释
    private static func highlightComments(in sql: String, attributed: inout AttributedString, fontSize: CGFloat = 14) {
        let nsString = sql as NSString

        // 单行注释 --
        let singleLinePattern = "--[^\\n]*"
        if let regex = try? NSRegularExpression(pattern: singleLinePattern) {
            let matches = regex.matches(in: sql, range: NSRange(location: 0, length: nsString.length))
            for match in matches {
                if let range = Range(match.range, in: sql) {
                    if let attrRange = Range(range, in: attributed) {
                        attributed[attrRange].foregroundColor = AppColors.sqlComment
                        attributed[attrRange].font = .monospacedSystemFont(ofSize: fontSize, weight: .regular)
                    }
                }
            }
        }

        // 多行注释 /* */
        let multiLinePattern = "/\\*[^*]*\\*+(?:[^/*][^*]*\\*+)*/"
        if let regex = try? NSRegularExpression(pattern: multiLinePattern, options: .dotMatchesLineSeparators) {
            let matches = regex.matches(in: sql, range: NSRange(location: 0, length: nsString.length))
            for match in matches {
                if let range = Range(match.range, in: sql) {
                    if let attrRange = Range(range, in: attributed) {
                        attributed[attrRange].foregroundColor = AppColors.sqlComment
                        attributed[attrRange].font = .monospacedSystemFont(ofSize: fontSize, weight: .regular)
                    }
                }
            }
        }
    }

    /// 高亮字符串
    private static func highlightStrings(in sql: String, attributed: inout AttributedString) {
        let nsString = sql as NSString
        let pattern = "'[^']*'"

        if let regex = try? NSRegularExpression(pattern: pattern) {
            let matches = regex.matches(in: sql, range: NSRange(location: 0, length: nsString.length))
            for match in matches {
                if let range = Range(match.range, in: sql) {
                    if let attrRange = Range(range, in: attributed) {
                        attributed[attrRange].foregroundColor = AppColors.sqlString
                    }
                }
            }
        }
    }

    /// 高亮数字
    private static func highlightNumbers(in sql: String, attributed: inout AttributedString) {
        let nsString = sql as NSString
        let pattern = "\\b\\d+(\\.\\d+)?\\b"

        if let regex = try? NSRegularExpression(pattern: pattern) {
            let matches = regex.matches(in: sql, range: NSRange(location: 0, length: nsString.length))
            for match in matches {
                if let range = Range(match.range, in: sql) {
                    if let attrRange = Range(range, in: attributed) {
                        attributed[attrRange].foregroundColor = AppColors.sqlNumber
                    }
                }
            }
        }
    }

    /// 高亮操作符
    private static func highlightOperators(in sql: String, attributed: inout AttributedString) {
        let operators = ["=", "!=", "<>", ">", "<", ">=", "<=", "+", "-", "*", "/"]

        for op in operators {
            var searchStart = sql.startIndex
            while let range = sql.range(of: op, range: searchStart..<sql.endIndex) {
                if let attrRange = Range(range, in: attributed) {
                    attributed[attrRange].foregroundColor = AppColors.sqlOperator
                }
                searchStart = range.upperBound
            }
        }
    }

    /// 高亮指定模式（关键字或函数）
    private static func highlightPattern(_ pattern: String, in upperSQL: String, originalText: String, attributed: inout AttributedString, color: Color, isBold: Bool, fontSize: CGFloat = 14) {
        let nsString = upperSQL as NSString
        let wordPattern = "\\b\(pattern)\\b"

        if let regex = try? NSRegularExpression(pattern: wordPattern) {
            let matches = regex.matches(in: upperSQL, range: NSRange(location: 0, length: nsString.length))
            for match in matches {
                if let range = Range(match.range, in: originalText) {
                    if let attrRange = Range(range, in: attributed) {
                        attributed[attrRange].foregroundColor = color
                        if isBold {
                            attributed[attrRange].font = .monospacedSystemFont(ofSize: fontSize, weight: .semibold)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - SQL 高亮文本视图

/// 显示高亮后的 SQL 文本（默认字体）
struct HighlightedSQLText: View {
    let sql: String
    var fontSize: CGFloat = 14

    var body: some View {
        Text(SQLSyntaxHighlighter.highlight(sql, fontSize: fontSize))
            .textSelection(.enabled)
    }
}
