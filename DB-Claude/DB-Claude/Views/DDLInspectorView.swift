import SwiftUI

struct DDLInspectorView: View {
    let tableName: String
    let ddl: String
    
    @State private var isCopied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 标题栏 - 扁平化
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "tablecells")
                    .font(.system(size: 14))
                    .foregroundColor(AppColors.accent)
                
                Text(tableName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppColors.primaryText)
                
                Spacer()
                
                // 复制按钮
                Button(action: copyDDL) {
                    HStack(spacing: AppSpacing.xxs) {
                        Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 11))
                        if isCopied {
                            Text("已复制")
                                .font(.system(size: 11))
                        }
                    }
                    .foregroundColor(isCopied ? AppColors.success : AppColors.secondaryText)
                    .padding(.horizontal, AppSpacing.sm)
                    .padding(.vertical, AppSpacing.xs)
                    .background(AppColors.tertiaryBackground)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.sm))
                }
                .buttonStyle(.plain)
                .help("复制 DDL")
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.sm)
            .background(AppColors.secondaryBackground)

            // DDL 内容 - 语法高亮 + 水平滚动
            GeometryReader { geometry in
                ScrollView([.horizontal, .vertical], showsIndicators: true) {
                    VStack(alignment: .leading, spacing: 0) {
                        SQLHighlightedText(sql: ddl)
                            .font(.system(size: 13, design: .monospaced))
                            .padding(AppSpacing.md)
                            .textSelection(.enabled)
                            .fixedSize(horizontal: true, vertical: false)
                        
                        Spacer(minLength: 0)
                    }
                    .frame(minWidth: geometry.size.width,
                           minHeight: geometry.size.height,
                           alignment: .topLeading)
                }
            }
            .background(AppColors.background)
        }
        .frame(minWidth: 200, maxWidth: .infinity)
    }
    
    private func copyDDL() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(ddl, forType: .string)
        
        withAnimation {
            isCopied = true
        }
        
        // 2秒后重置状态
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                isCopied = false
            }
        }
    }
}

// MARK: - SQL 语法高亮

/// SQL 语法高亮颜色
enum SQLSyntaxColors {
    // 关键字 - 蓝色
    static let keyword = Color(red: 0.0, green: 0.478, blue: 1.0)
    // 数据类型 - 紫色
    static let dataType = Color(red: 0.608, green: 0.318, blue: 0.878)
    // 函数 - 橙色
    static let function = Color(red: 0.937, green: 0.549, blue: 0.0)
    // 字符串 - 红色
    static let string = Color(red: 0.831, green: 0.286, blue: 0.267)
    // 数字 - 青色
    static let number = Color(red: 0.110, green: 0.678, blue: 0.659)
    // 注释 - 灰色
    static let comment = Color.gray
    // 普通文本
    static let plain = Color.primary
}

/// SQL 语法高亮文本视图
struct SQLHighlightedText: View {
    let sql: String
    
    var body: some View {
        highlightedText
    }
    
    private var highlightedText: Text {
        let tokens = tokenize(sql)
        var result = Text("")
        
        for token in tokens {
            let styledText = Text(token.text)
                .foregroundColor(color(for: token.type))
            result = result + styledText
        }
        
        return result
    }
    
    private func color(for type: TokenType) -> Color {
        switch type {
        case .keyword:
            return SQLSyntaxColors.keyword
        case .dataType:
            return SQLSyntaxColors.dataType
        case .function:
            return SQLSyntaxColors.function
        case .string:
            return SQLSyntaxColors.string
        case .number:
            return SQLSyntaxColors.number
        case .comment:
            return SQLSyntaxColors.comment
        case .plain:
            return SQLSyntaxColors.plain
        }
    }
    
    private enum TokenType {
        case keyword
        case dataType
        case function
        case string
        case number
        case comment
        case plain
    }
    
    private struct Token {
        let text: String
        let type: TokenType
    }
    
    // SQL 关键字列表
    private static let keywords: Set<String> = [
        "CREATE", "TABLE", "DROP", "ALTER", "INSERT", "INTO", "VALUES", "UPDATE", "SET",
        "DELETE", "FROM", "SELECT", "WHERE", "AND", "OR", "NOT", "NULL", "DEFAULT",
        "PRIMARY", "KEY", "FOREIGN", "REFERENCES", "UNIQUE", "INDEX", "ON", "AS",
        "JOIN", "LEFT", "RIGHT", "INNER", "OUTER", "CROSS", "ORDER", "BY", "ASC", "DESC",
        "GROUP", "HAVING", "LIMIT", "OFFSET", "UNION", "ALL", "DISTINCT", "EXISTS",
        "IN", "BETWEEN", "LIKE", "IS", "CASE", "WHEN", "THEN", "ELSE", "END",
        "IF", "AUTO_INCREMENT", "AUTOINCREMENT", "ENGINE", "CHARSET", "COLLATE",
        "CONSTRAINT", "CHECK", "CASCADE", "RESTRICT", "NO", "ACTION", "COMMENT",
        "UNSIGNED", "ZEROFILL", "BINARY", "AFTER", "FIRST", "ADD", "COLUMN", "MODIFY",
        "CHANGE", "RENAME", "TO", "TEMPORARY", "VIEW", "TRIGGER", "PROCEDURE", "FUNCTION",
        "BEGIN", "COMMIT", "ROLLBACK", "TRANSACTION", "LOCK", "UNLOCK", "TABLES",
        "WITHOUT", "ROWID", "STRICT", "VIRTUAL", "STORED", "GENERATED", "ALWAYS"
    ]
    
    // SQL 数据类型列表
    private static let dataTypes: Set<String> = [
        "INT", "INTEGER", "TINYINT", "SMALLINT", "MEDIUMINT", "BIGINT",
        "FLOAT", "DOUBLE", "DECIMAL", "NUMERIC", "REAL",
        "CHAR", "VARCHAR", "TEXT", "TINYTEXT", "MEDIUMTEXT", "LONGTEXT",
        "BLOB", "TINYBLOB", "MEDIUMBLOB", "LONGBLOB",
        "DATE", "TIME", "DATETIME", "TIMESTAMP", "YEAR",
        "BOOLEAN", "BOOL", "BIT", "JSON", "ENUM", "SET",
        "GEOMETRY", "POINT", "LINESTRING", "POLYGON",
        "UUID", "SERIAL", "MONEY", "BYTEA", "ARRAY", "CIDR", "INET", "MACADDR"
    ]
    
    // SQL 函数列表
    private static let functions: Set<String> = [
        "COUNT", "SUM", "AVG", "MIN", "MAX", "COALESCE", "NULLIF", "IFNULL",
        "CONCAT", "SUBSTRING", "LENGTH", "UPPER", "LOWER", "TRIM", "REPLACE",
        "NOW", "CURRENT_DATE", "CURRENT_TIME", "CURRENT_TIMESTAMP",
        "DATE_FORMAT", "DATE_ADD", "DATE_SUB", "DATEDIFF", "YEAR", "MONTH", "DAY",
        "ROUND", "FLOOR", "CEIL", "CEILING", "ABS", "MOD", "POWER", "SQRT",
        "CAST", "CONVERT", "ISNULL", "NVL", "DECODE"
    ]
    
    private func tokenize(_ sql: String) -> [Token] {
        var tokens: [Token] = []
        var currentIndex = sql.startIndex
        
        while currentIndex < sql.endIndex {
            let remaining = String(sql[currentIndex...])
            
            // 检查字符串（单引号或双引号）
            if let firstChar = remaining.first, firstChar == "'" || firstChar == "\"" {
                let quote = firstChar
                var endIndex = remaining.index(after: remaining.startIndex)
                while endIndex < remaining.endIndex {
                    if remaining[endIndex] == quote {
                        endIndex = remaining.index(after: endIndex)
                        break
                    }
                    endIndex = remaining.index(after: endIndex)
                }
                let stringContent = String(remaining[remaining.startIndex..<endIndex])
                tokens.append(Token(text: stringContent, type: .string))
                currentIndex = sql.index(currentIndex, offsetBy: stringContent.count)
                continue
            }
            
            // 检查注释（-- 或 /* */）
            if remaining.hasPrefix("--") {
                if let newlineIndex = remaining.firstIndex(of: "\n") {
                    let comment = String(remaining[remaining.startIndex..<newlineIndex])
                    tokens.append(Token(text: comment, type: .comment))
                    currentIndex = sql.index(currentIndex, offsetBy: comment.count)
                } else {
                    tokens.append(Token(text: remaining, type: .comment))
                    break
                }
                continue
            }
            
            if remaining.hasPrefix("/*") {
                if let endRange = remaining.range(of: "*/") {
                    let comment = String(remaining[remaining.startIndex...endRange.upperBound])
                    tokens.append(Token(text: comment, type: .comment))
                    currentIndex = sql.index(currentIndex, offsetBy: comment.count)
                } else {
                    tokens.append(Token(text: remaining, type: .comment))
                    break
                }
                continue
            }
            
            // 检查数字
            if let firstChar = remaining.first, firstChar.isNumber || (firstChar == "-" && remaining.count > 1 && remaining[remaining.index(after: remaining.startIndex)].isNumber) {
                var endIndex = remaining.startIndex
                if firstChar == "-" {
                    endIndex = remaining.index(after: endIndex)
                }
                while endIndex < remaining.endIndex {
                    let char = remaining[endIndex]
                    if char.isNumber || char == "." {
                        endIndex = remaining.index(after: endIndex)
                    } else {
                        break
                    }
                }
                let number = String(remaining[remaining.startIndex..<endIndex])
                tokens.append(Token(text: number, type: .number))
                currentIndex = sql.index(currentIndex, offsetBy: number.count)
                continue
            }
            
            // 检查单词（关键字、数据类型、函数）
            if let firstChar = remaining.first, firstChar.isLetter || firstChar == "_" {
                var endIndex = remaining.startIndex
                while endIndex < remaining.endIndex {
                    let char = remaining[endIndex]
                    if char.isLetter || char.isNumber || char == "_" {
                        endIndex = remaining.index(after: endIndex)
                    } else {
                        break
                    }
                }
                let word = String(remaining[remaining.startIndex..<endIndex])
                let upperWord = word.uppercased()
                
                let tokenType: TokenType
                if Self.keywords.contains(upperWord) {
                    tokenType = .keyword
                } else if Self.dataTypes.contains(upperWord) {
                    tokenType = .dataType
                } else if Self.functions.contains(upperWord) {
                    tokenType = .function
                } else {
                    tokenType = .plain
                }
                
                tokens.append(Token(text: word, type: tokenType))
                currentIndex = sql.index(currentIndex, offsetBy: word.count)
                continue
            }
            
            // 其他字符（符号、空格、换行等）
            tokens.append(Token(text: String(remaining.first!), type: .plain))
            currentIndex = sql.index(after: currentIndex)
        }
        
        return tokens
    }
}

#Preview {
    DDLInspectorView(
        tableName: "users",
        ddl: """
CREATE TABLE `users` (
    `id` INTEGER PRIMARY KEY AUTOINCREMENT,
    `name` VARCHAR(255) NOT NULL,
    `email` VARCHAR(255) NOT NULL UNIQUE,
    `age` INT DEFAULT 0,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `balance` DECIMAL(10, 2) NOT NULL DEFAULT 0.00
);
-- This is a comment
CREATE INDEX idx_users_email ON users(email);
"""
    )
    .frame(width: 400, height: 300)
}
