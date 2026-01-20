import Foundation
import AppKit

/// SQL 语法定义
struct SQLSyntax {
    
    // MARK: - MySQL 关键字（完整列表）
    static let keywords: Set<String> = [
        // DDL
        "CREATE", "ALTER", "DROP", "TRUNCATE", "RENAME", "COMMENT",
        "TABLE", "DATABASE", "SCHEMA", "INDEX", "VIEW", "TRIGGER", "PROCEDURE", "FUNCTION", "EVENT",
        "COLUMN", "CONSTRAINT", "PRIMARY", "KEY", "FOREIGN", "REFERENCES", "UNIQUE", "FULLTEXT", "SPATIAL",
        "ADD", "MODIFY", "CHANGE", "ENGINE", "CHARSET", "COLLATE", "AUTO_INCREMENT", "DEFAULT",
        
        // DML
        "SELECT", "INSERT", "UPDATE", "DELETE", "REPLACE", "MERGE",
        "FROM", "INTO", "VALUES", "SET", "WHERE", "AND", "OR", "NOT", "IN", "BETWEEN", "LIKE", "REGEXP", "RLIKE",
        "IS", "NULL", "TRUE", "FALSE", "UNKNOWN",
        "ORDER", "BY", "ASC", "DESC", "LIMIT", "OFFSET", "FETCH", "FIRST", "NEXT", "ROWS", "ONLY",
        "GROUP", "HAVING", "DISTINCT", "ALL", "AS", "ON", "USING",
        
        // JOIN
        "JOIN", "INNER", "LEFT", "RIGHT", "OUTER", "CROSS", "NATURAL", "STRAIGHT_JOIN",
        
        // UNION
        "UNION", "INTERSECT", "EXCEPT", "MINUS",
        
        // 子查询
        "EXISTS", "ANY", "SOME",
        
        // CASE
        "CASE", "WHEN", "THEN", "ELSE", "END",
        
        // 事务
        "BEGIN", "START", "TRANSACTION", "COMMIT", "ROLLBACK", "SAVEPOINT", "RELEASE",
        "LOCK", "UNLOCK", "TABLES", "READ", "WRITE",
        
        // 权限
        "GRANT", "REVOKE", "PRIVILEGES", "TO", "IDENTIFIED", "WITH", "OPTION",
        
        // 其他
        "EXPLAIN", "DESCRIBE", "DESC", "SHOW", "USE", "ANALYZE", "OPTIMIZE", "CHECK", "REPAIR",
        "FLUSH", "RESET", "PURGE", "LOAD", "DATA", "INFILE", "OUTFILE", "DUMPFILE",
        "CALL", "DO", "HANDLER", "HELP",
        "IF", "ELSEIF", "ITERATE", "LEAVE", "LOOP", "REPEAT", "UNTIL", "WHILE", "RETURN",
        "DECLARE", "CURSOR", "OPEN", "CLOSE", "FOR",
        "PREPARE", "EXECUTE", "DEALLOCATE",
        
        // 数据类型
        "INT", "INTEGER", "TINYINT", "SMALLINT", "MEDIUMINT", "BIGINT",
        "FLOAT", "DOUBLE", "DECIMAL", "NUMERIC", "REAL",
        "CHAR", "VARCHAR", "TINYTEXT", "TEXT", "MEDIUMTEXT", "LONGTEXT",
        "BINARY", "VARBINARY", "TINYBLOB", "BLOB", "MEDIUMBLOB", "LONGBLOB",
        "DATE", "TIME", "DATETIME", "TIMESTAMP", "YEAR",
        "ENUM", "SET", "JSON", "GEOMETRY", "POINT", "LINESTRING", "POLYGON",
        "BIT", "BOOL", "BOOLEAN", "SERIAL",
        "UNSIGNED", "SIGNED", "ZEROFILL",
        
        // 约束
        "NOT", "NULL", "DEFAULT", "UNIQUE", "PRIMARY", "KEY", "CHECK", "CONSTRAINT",
        
        // 索引
        "INDEX", "USING", "BTREE", "HASH", "VISIBLE", "INVISIBLE",
        
        // 分区
        "PARTITION", "PARTITIONS", "SUBPARTITION", "RANGE", "LIST", "HASH", "LINEAR",
        
        // 其他关键字
        "TEMPORARY", "IF", "EXISTS", "CASCADE", "RESTRICT", "NO", "ACTION",
        "CURRENT_TIMESTAMP", "NOW", "CURRENT_DATE", "CURRENT_TIME", "CURRENT_USER",
        "DUAL", "FORCE", "IGNORE", "LOW_PRIORITY", "HIGH_PRIORITY", "DELAYED", "QUICK",
        "SQL_CALC_FOUND_ROWS", "SQL_NO_CACHE", "SQL_CACHE", "SQL_BUFFER_RESULT",
        "STRAIGHT_JOIN", "NATURAL", "CROSS", "OUTER", "INNER",
        "ALGORITHM", "DEFINER", "INVOKER", "SQL", "SECURITY",
        "DETERMINISTIC", "CONTAINS", "MODIFIES", "READS", "LANGUAGE",
        "INTERVAL", "SECOND", "MINUTE", "HOUR", "DAY", "WEEK", "MONTH", "QUARTER", "YEAR",
        "SEPARATOR", "ESCAPED", "TERMINATED", "ENCLOSED", "OPTIONALLY", "LINES",
        "STARTING", "ROWS", "PRECEDING", "FOLLOWING", "UNBOUNDED", "CURRENT", "ROW",
        "OVER", "WINDOW", "GROUPS", "EXCLUDE", "TIES", "OTHERS",
        "RECURSIVE", "CTE", "LATERAL", "MATERIALIZED"
    ]
    
    // MARK: - MySQL 内置函数
    static let functions: Set<String> = [
        // 聚合函数
        "COUNT", "SUM", "AVG", "MIN", "MAX", "GROUP_CONCAT", "JSON_ARRAYAGG", "JSON_OBJECTAGG",
        "STD", "STDDEV", "STDDEV_POP", "STDDEV_SAMP", "VAR_POP", "VAR_SAMP", "VARIANCE",
        "BIT_AND", "BIT_OR", "BIT_XOR",
        
        // 字符串函数
        "CONCAT", "CONCAT_WS", "SUBSTR", "SUBSTRING", "LEFT", "RIGHT", "LENGTH", "CHAR_LENGTH",
        "UPPER", "LOWER", "UCASE", "LCASE", "TRIM", "LTRIM", "RTRIM", "LPAD", "RPAD",
        "REPLACE", "REVERSE", "REPEAT", "SPACE", "INSERT", "LOCATE", "POSITION", "INSTR",
        "FIELD", "FIND_IN_SET", "MAKE_SET", "EXPORT_SET", "FORMAT", "BIN", "OCT", "HEX", "UNHEX",
        "ASCII", "ORD", "CHAR", "QUOTE", "SOUNDEX", "ELT",
        "SUBSTRING_INDEX", "MID", "STRCMP", "REGEXP_LIKE", "REGEXP_REPLACE", "REGEXP_INSTR", "REGEXP_SUBSTR",
        
        // 数值函数
        "ABS", "CEIL", "CEILING", "FLOOR", "ROUND", "TRUNCATE", "MOD", "DIV",
        "POWER", "POW", "SQRT", "EXP", "LOG", "LOG2", "LOG10", "LN",
        "SIN", "COS", "TAN", "ASIN", "ACOS", "ATAN", "ATAN2", "COT",
        "DEGREES", "RADIANS", "PI", "RAND", "SIGN", "GREATEST", "LEAST",
        "CONV", "CRC32",
        
        // 日期时间函数
        "NOW", "CURDATE", "CURTIME", "CURRENT_DATE", "CURRENT_TIME", "CURRENT_TIMESTAMP",
        "SYSDATE", "LOCALTIME", "LOCALTIMESTAMP", "UTC_DATE", "UTC_TIME", "UTC_TIMESTAMP",
        "DATE", "TIME", "DATETIME", "TIMESTAMP", "YEAR", "MONTH", "DAY", "HOUR", "MINUTE", "SECOND",
        "DAYOFWEEK", "DAYOFMONTH", "DAYOFYEAR", "WEEKDAY", "WEEK", "WEEKOFYEAR", "YEARWEEK",
        "QUARTER", "MONTHNAME", "DAYNAME", "LAST_DAY", "MAKEDATE", "MAKETIME",
        "DATE_ADD", "DATE_SUB", "ADDDATE", "SUBDATE", "ADDTIME", "SUBTIME", "TIMEDIFF", "DATEDIFF",
        "DATE_FORMAT", "TIME_FORMAT", "GET_FORMAT", "STR_TO_DATE", "FROM_UNIXTIME", "UNIX_TIMESTAMP",
        "PERIOD_ADD", "PERIOD_DIFF", "TO_DAYS", "FROM_DAYS", "TO_SECONDS", "TIME_TO_SEC", "SEC_TO_TIME",
        "EXTRACT", "TIMESTAMPADD", "TIMESTAMPDIFF", "CONVERT_TZ",
        
        // 条件函数
        "IF", "IFNULL", "NULLIF", "COALESCE", "CASE", "WHEN", "ISNULL",
        
        // 类型转换
        "CAST", "CONVERT", "BINARY",
        
        // JSON 函数
        "JSON_EXTRACT", "JSON_UNQUOTE", "JSON_SET", "JSON_INSERT", "JSON_REPLACE", "JSON_REMOVE",
        "JSON_ARRAY", "JSON_OBJECT", "JSON_QUOTE", "JSON_CONTAINS", "JSON_CONTAINS_PATH",
        "JSON_DEPTH", "JSON_LENGTH", "JSON_TYPE", "JSON_VALID", "JSON_KEYS", "JSON_SEARCH",
        "JSON_MERGE", "JSON_MERGE_PATCH", "JSON_MERGE_PRESERVE", "JSON_PRETTY", "JSON_STORAGE_SIZE",
        "JSON_TABLE", "JSON_VALUE",
        
        // 窗口函数
        "ROW_NUMBER", "RANK", "DENSE_RANK", "PERCENT_RANK", "CUME_DIST", "NTILE",
        "LAG", "LEAD", "FIRST_VALUE", "LAST_VALUE", "NTH_VALUE",
        
        // 其他函数
        "DATABASE", "SCHEMA", "USER", "CURRENT_USER", "SESSION_USER", "SYSTEM_USER",
        "VERSION", "CONNECTION_ID", "LAST_INSERT_ID", "ROW_COUNT", "FOUND_ROWS",
        "UUID", "UUID_SHORT", "UUID_TO_BIN", "BIN_TO_UUID",
        "MD5", "SHA", "SHA1", "SHA2", "AES_ENCRYPT", "AES_DECRYPT", "COMPRESS", "UNCOMPRESS",
        "ENCODE", "DECODE", "DES_ENCRYPT", "DES_DECRYPT", "ENCRYPT", "PASSWORD", "OLD_PASSWORD",
        "BENCHMARK", "SLEEP", "GET_LOCK", "RELEASE_LOCK", "IS_FREE_LOCK", "IS_USED_LOCK",
        "MASTER_POS_WAIT", "WAIT_FOR_EXECUTED_GTID_SET",
        "ANY_VALUE", "DEFAULT", "VALUES", "GROUPING",
        
        // 空间函数
        "ST_AREA", "ST_ASBINARY", "ST_ASGEOJSON", "ST_ASTEXT", "ST_BUFFER", "ST_CENTROID",
        "ST_CONTAINS", "ST_CROSSES", "ST_DIFFERENCE", "ST_DIMENSION", "ST_DISJOINT", "ST_DISTANCE",
        "ST_EQUALS", "ST_GEOMFROMTEXT", "ST_GEOMFROMWKB", "ST_INTERSECTION", "ST_INTERSECTS",
        "ST_ISEMPTY", "ST_ISSIMPLE", "ST_ISVALID", "ST_LENGTH", "ST_OVERLAPS", "ST_SRID",
        "ST_STARTPOINT", "ST_ENDPOINT", "ST_ENVELOPE", "ST_EXTERIORRING", "ST_GEOMETRYN",
        "ST_GEOMETRYTYPE", "ST_INTERIORRINGN", "ST_NUMGEOMETRIES", "ST_NUMINTERIORRINGS",
        "ST_NUMPOINTS", "ST_POINTN", "ST_SIMPLIFY", "ST_SYMDIFFERENCE", "ST_TOUCHES", "ST_UNION",
        "ST_WITHIN", "ST_X", "ST_Y", "ST_LATITUDE", "ST_LONGITUDE"
    ]
    
    // MARK: - 运算符
    static let operators: Set<String> = [
        "+", "-", "*", "/", "%", "=", "!=", "<>", "<", ">", "<=", ">=",
        "&", "|", "^", "~", "<<", ">>",
        ":=", "->", "->>", "&&", "||", "!",
        "DIV", "MOD", "XOR"
    ]
    
    // MARK: - 颜色定义
    struct Colors {
        static let keyword = NSColor(red: 0.78, green: 0.22, blue: 0.55, alpha: 1.0)      // 紫红色
        static let function = NSColor(red: 0.2, green: 0.6, blue: 0.86, alpha: 1.0)       // 蓝色
        static let string = NSColor(red: 0.84, green: 0.47, blue: 0.17, alpha: 1.0)       // 橙色
        static let number = NSColor(red: 0.11, green: 0.63, blue: 0.95, alpha: 1.0)       // 浅蓝色
        static let comment = NSColor(red: 0.42, green: 0.48, blue: 0.54, alpha: 1.0)      // 灰色
        static let identifier = NSColor(red: 0.95, green: 0.76, blue: 0.26, alpha: 1.0)   // 黄色（表名/字段名）
        static let `operator` = NSColor(red: 0.68, green: 0.71, blue: 0.75, alpha: 1.0)   // 浅灰色
        static let plain = NSColor.textColor                                               // 默认文本色
        static let background = NSColor.textBackgroundColor                                // 背景色
    }
    
    // MARK: - 字体
    static func font(size: CGFloat = 13) -> NSFont {
        return NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
    }
}

// MARK: - 补全项类型
enum CompletionItemType {
    case keyword
    case function
    case table
    case column
    case database
    
    var icon: String {
        switch self {
        case .keyword: return "k"
        case .function: return "ƒ"
        case .table: return "T"
        case .column: return "C"
        case .database: return "D"
        }
    }
    
    var color: NSColor {
        switch self {
        case .keyword: return SQLSyntax.Colors.keyword
        case .function: return SQLSyntax.Colors.function
        case .table: return SQLSyntax.Colors.identifier
        case .column: return SQLSyntax.Colors.identifier.withAlphaComponent(0.8)
        case .database: return NSColor.systemTeal
        }
    }
}

// MARK: - 补全项
struct CompletionItem: Identifiable, Hashable {
    let id = UUID()
    let text: String
    let type: CompletionItemType
    let detail: String?
    
    init(text: String, type: CompletionItemType, detail: String? = nil) {
        self.text = text
        self.type = type
        self.detail = detail
    }
    
    static func == (lhs: CompletionItem, rhs: CompletionItem) -> Bool {
        return lhs.text == rhs.text && lhs.type == rhs.type
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(text)
        hasher.combine(type.icon)
    }
}
