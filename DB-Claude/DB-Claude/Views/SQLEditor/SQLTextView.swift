import SwiftUI
import AppKit

/// SQL 编辑器视图 - 支持语法高亮和自动补全
struct SQLTextView: NSViewRepresentable {
    @Binding var text: String
    var tables: [String]
    var columns: [String: [String]]  // tableName -> columns
    var fontSize: CGFloat = 13  // 自定义字体大小
    var onExecute: (() -> Void)?
    var onExecuteSelected: ((String) -> Void)?  // 执行选中的 SQL
    var onExplain: ((String) -> Void)?  // EXPLAIN SQL
    var onFormat: (() -> Void)?  // 格式化 SQL
    var onShowToast: ((String) -> Void)?  // Toast 回调
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        
        let textView = SQLEditorTextView()
        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.allowsUndo = true
        textView.isEditable = true
        textView.isSelectable = true
        textView.font = SQLSyntax.font(size: fontSize)
        textView.backgroundColor = NSColor.textBackgroundColor
        textView.insertionPointColor = NSColor.textColor
        textView.textColor = SQLSyntax.Colors.plain
        textView.autoresizingMask = [.width]
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainerInset = NSSize(width: 8, height: 8)
        
        // 设置自动换行
        textView.textContainer?.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        
        // 关联 coordinator
        textView.completionDelegate = context.coordinator
        context.coordinator.textView = textView
        
        scrollView.documentView = textView
        
        // 初始化文本和高亮
        textView.string = text
        context.coordinator.applyHighlighting()
        
        return scrollView
    }
    
    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? SQLEditorTextView else { return }
        
        // 更新补全数据源
        context.coordinator.tables = tables
        context.coordinator.columns = columns
        context.coordinator.fontSize = fontSize
        
        // 更新字体大小
        if textView.font?.pointSize != fontSize {
            textView.font = SQLSyntax.font(size: fontSize)
            context.coordinator.applyHighlighting()
        }
        
        // 只有当文本发生变化时才更新
        if textView.string != text {
            let selectedRange = textView.selectedRange()
            textView.string = text
            context.coordinator.applyHighlighting()
            
            // 恢复光标位置
            if selectedRange.location <= text.count {
                textView.setSelectedRange(selectedRange)
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    // MARK: - Coordinator
    class Coordinator: NSObject, NSTextViewDelegate, CompletionDelegate {
        var parent: SQLTextView
        weak var textView: SQLEditorTextView?
        var tables: [String] = []
        var columns: [String: [String]] = [:]
        var fontSize: CGFloat = 13
        
        // 补全窗口
        private var completionWindow: CompletionWindow?
        private var completionItems: [CompletionItem] = []
        private var currentWord: String = ""
        private var currentWordRange: NSRange = NSRange(location: 0, length: 0)
        
        // 中文标点转英文标点映射
        private let chinesePunctuationMap: [Character: Character] = [
            "，": ",",   // 逗号
            "。": ".",   // 句号
            "；": ";",   // 分号
            "：": ":",   // 冒号
            "\u{201C}": "\"",  // 左双引号 "
            "\u{201D}": "\"",  // 右双引号 "
            "\u{2018}": "'",   // 左单引号 '
            "\u{2019}": "'",   // 右单引号 '
            "（": "(",   // 左括号
            "）": ")",   // 右括号
            "【": "[",   // 左方括号
            "】": "]",   // 右方括号
            "！": "!",   // 感叹号
            "？": "?",   // 问号
            "、": ",",   // 顿号 -> 逗号
            "《": "<",   // 左书名号
            "》": ">",   // 右书名号
            "～": "~",   // 波浪号
            "｜": "|",   // 竖线
            "＋": "+",   // 加号
            "－": "-",   // 减号
            "＝": "=",   // 等号
            "＊": "*",   // 星号
            "／": "/",   // 斜杠
            "％": "%",   // 百分号
            "＆": "&",   // and 符号
            "＾": "^",   // 脱字符
            "＠": "@",   // at 符号
            "＃": "#",   // 井号
            "＄": "$",   // 美元符号
            "｛": "{",   // 左花括号
            "｝": "}",   // 右花括号
        ]
        
        init(_ parent: SQLTextView) {
            self.parent = parent
            self.tables = parent.tables
            self.columns = parent.columns
            self.fontSize = parent.fontSize
        }
        
        /// 获取选中的文本
        func getSelectedText() -> String? {
            guard let textView = textView else { return nil }
            let selectedRange = textView.selectedRange()
            guard selectedRange.length > 0 else { return nil }
            
            let text = textView.string as NSString
            return text.substring(with: selectedRange)
        }
        
        /// 执行查询（如果有选中文本则执行选中的，否则执行全部）
        func executeQuery() {
            if let selectedText = getSelectedText(), !selectedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                parent.onExecuteSelected?(selectedText)
            } else {
                parent.onExecute?()
            }
        }
        
        /// EXPLAIN 查询（如果有选中文本则 EXPLAIN 选中的，否则 EXPLAIN 全部）
        func explainQuery() {
            let sqlToExplain: String
            if let selectedText = getSelectedText(), !selectedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                sqlToExplain = selectedText
            } else {
                sqlToExplain = parent.text
            }
            parent.onExplain?(sqlToExplain)
        }
        
        /// 格式化选中内容或全部（如果有选中则只格式化选中部分）
        func formatSelectedOrAll() {
            guard let textView = textView else { return }
            let selectedRange = textView.selectedRange()
            
            if selectedRange.length > 0 {
                // 格式化选中部分
                let text = textView.string as NSString
                let selectedText = text.substring(with: selectedRange)
                let formatted = formatSQLText(selectedText)
                
                // 替换选中内容
                textView.textStorage?.beginEditing()
                textView.textStorage?.replaceCharacters(in: selectedRange, with: formatted)
                textView.textStorage?.endEditing()
                
                // 更新绑定
                parent.text = textView.string
                applyHighlighting()
                
                parent.onShowToast?("已格式化选中内容")
            } else {
                // 格式化全部
                parent.onFormat?()
            }
        }
        
        /// 格式化 SQL 文本
        private func formatSQLText(_ sql: String) -> String {
            var formatted = sql
            
            // 关键字大写
            let keywords = [
                "ORDER BY", "GROUP BY", "LEFT JOIN", "RIGHT JOIN", "INNER JOIN", "OUTER JOIN",
                "SELECT", "UPDATE", "DELETE", "INSERT", "CREATE", "ALTER", "DROP",
                "FROM", "WHERE", "AND", "OR", "NOT", "IN", "BETWEEN", "LIKE",
                "JOIN", "LEFT", "RIGHT", "INNER", "OUTER", "ON", "USING",
                "HAVING", "LIMIT", "OFFSET", "UNION", "INTO", "VALUES", "SET",
                "AS", "DISTINCT", "ALL", "ASC", "DESC", "NULL", "IS"
            ]
            
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
            
            return formatted
        }
        
        // MARK: - NSTextViewDelegate
        
        // 拦截输入，自动转换中文标点
        func textView(_ textView: NSTextView, shouldChangeTextIn affectedCharRange: NSRange, replacementString: String?) -> Bool {
            guard let replacement = replacementString, !replacement.isEmpty else {
                return true
            }
            
            // 检查是否包含中文标点
            var convertedString = ""
            var hasConversion = false
            var convertedChars: [String] = []
            
            for char in replacement {
                if let englishChar = chinesePunctuationMap[char] {
                    convertedString.append(englishChar)
                    hasConversion = true
                    convertedChars.append("\(char) → \(englishChar)")
                } else {
                    convertedString.append(char)
                }
            }
            
            // 如果有转换，手动插入转换后的文本
            if hasConversion {
                // 使用转换后的文本替换
                if let textStorage = textView.textStorage {
                    textStorage.beginEditing()
                    textStorage.replaceCharacters(in: affectedCharRange, with: convertedString)
                    textStorage.endEditing()
                    
                    // 移动光标
                    let newLocation = affectedCharRange.location + convertedString.count
                    textView.setSelectedRange(NSRange(location: newLocation, length: 0))
                    
                    // 更新绑定
                    parent.text = textView.string
                    
                    // 应用高亮
                    applyHighlighting()
                    
                    // 触发补全
                    triggerCompletion()
                    
                    // 显示 toast
                    let message = "已自动转换: " + convertedChars.joined(separator: ", ")
                    parent.onShowToast?(message)
                }
                
                return false  // 阻止原始输入
            }
            
            return true
        }
        
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            
            // 自动将关键字转换为大写
            autoUppercaseKeywords(in: textView)
            
            // 更新绑定的文本
            parent.text = textView.string
            
            // 应用语法高亮
            applyHighlighting()
            
            // 触发自动补全
            triggerCompletion()
        }
        
        /// 自动将刚输入的关键字转换为大写
        private func autoUppercaseKeywords(in textView: NSTextView) {
            let text = textView.string as NSString
            let cursorLocation = textView.selectedRange().location
            
            // 只在光标前有内容时处理
            guard cursorLocation > 0 else { return }
            
            // 获取光标前的字符
            let charBeforeCursor = text.character(at: cursorLocation - 1)
            guard let scalar = UnicodeScalar(charBeforeCursor) else { return }
            
            // 只在输入分隔符后检查（空格、换行、逗号、括号等）
            let separators = CharacterSet(charactersIn: " \n\t,;()[]")
            guard separators.contains(scalar) else { return }
            
            // 向前查找上一个单词
            let wordEnd = cursorLocation - 1
            var wordStart = wordEnd
            
            // 跳过分隔符
            while wordStart > 0 {
                let char = text.character(at: wordStart - 1)
                if let s = UnicodeScalar(char), separators.contains(s) {
                    break
                }
                wordStart -= 1
            }
            
            // 获取单词
            let wordLength = wordEnd - wordStart
            guard wordLength > 0 && wordLength <= 20 else { return }  // 关键字不会超过20个字符
            
            let wordRange = NSRange(location: wordStart, length: wordLength)
            let word = text.substring(with: wordRange)
            let upperWord = word.uppercased()
            
            // 检查是否是关键字
            if SQLSyntax.keywords.contains(upperWord) && word != upperWord {
                // 需要转换为大写
                textView.textStorage?.beginEditing()
                textView.textStorage?.replaceCharacters(in: wordRange, with: upperWord)
                textView.textStorage?.endEditing()
                
                // 恢复光标位置
                textView.setSelectedRange(NSRange(location: cursorLocation, length: 0))
            }
        }
        
        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            // 处理 Tab 键 - 选择补全项
            if commandSelector == #selector(NSResponder.insertTab(_:)) {
                if let window = completionWindow, window.isVisible {
                    insertSelectedCompletion()
                    return true
                }
            }
            
            // 处理 Escape 键 - 关闭补全窗口
            if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
                hideCompletion()
                return true
            }
            
            // 处理 Enter 键 - 选择补全项或执行查询
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                if let window = completionWindow, window.isVisible {
                    insertSelectedCompletion()
                    return true
                }
            }
            
            // 处理上下箭头 - 导航补全列表
            if commandSelector == #selector(NSResponder.moveUp(_:)) {
                if let window = completionWindow, window.isVisible {
                    window.selectPrevious()
                    return true
                }
            }
            
            if commandSelector == #selector(NSResponder.moveDown(_:)) {
                if let window = completionWindow, window.isVisible {
                    window.selectNext()
                    return true
                }
            }
            
            // Command + Enter 执行查询（支持选中执行）
            if commandSelector == #selector(NSResponder.insertNewlineIgnoringFieldEditor(_:)) {
                executeQuery()
                return true
            }
            
            return false
        }
        
        // MARK: - 语法高亮
        func applyHighlighting() {
            guard let textView = textView else { return }
            let text = textView.string
            guard !text.isEmpty else { return }
            
            let fullRange = NSRange(location: 0, length: text.count)
            
            // 保存当前选择
            let selectedRange = textView.selectedRange()
            
            // 重置为默认样式
            textView.textStorage?.beginEditing()
            textView.textStorage?.setAttributes([
                .font: SQLSyntax.font(size: fontSize),
                .foregroundColor: SQLSyntax.Colors.plain
            ], range: fullRange)
            
            // 应用高亮
            highlightStrings(in: text, textStorage: textView.textStorage)
            highlightComments(in: text, textStorage: textView.textStorage)
            highlightKeywords(in: text, textStorage: textView.textStorage)
            highlightFunctions(in: text, textStorage: textView.textStorage)
            highlightNumbers(in: text, textStorage: textView.textStorage)
            
            textView.textStorage?.endEditing()
            
            // 恢复选择
            textView.setSelectedRange(selectedRange)
        }
        
        private func highlightStrings(in text: String, textStorage: NSTextStorage?) {
            // 单引号字符串
            let singleQuotePattern = "'(?:[^'\\\\]|\\\\.)*'"
            highlightPattern(singleQuotePattern, in: text, color: SQLSyntax.Colors.string, textStorage: textStorage)
            
            // 双引号字符串
            let doubleQuotePattern = "\"(?:[^\"\\\\]|\\\\.)*\""
            highlightPattern(doubleQuotePattern, in: text, color: SQLSyntax.Colors.string, textStorage: textStorage)
            
            // 反引号标识符
            let backtickPattern = "`[^`]+`"
            highlightPattern(backtickPattern, in: text, color: SQLSyntax.Colors.identifier, textStorage: textStorage)
        }
        
        private func highlightComments(in text: String, textStorage: NSTextStorage?) {
            // 单行注释 --
            let singleLinePattern = "--[^\n]*"
            highlightPattern(singleLinePattern, in: text, color: SQLSyntax.Colors.comment, textStorage: textStorage)
            
            // 单行注释 #
            let hashPattern = "#[^\n]*"
            highlightPattern(hashPattern, in: text, color: SQLSyntax.Colors.comment, textStorage: textStorage)
            
            // 多行注释 /* */
            let multiLinePattern = "/\\*[\\s\\S]*?\\*/"
            highlightPattern(multiLinePattern, in: text, color: SQLSyntax.Colors.comment, textStorage: textStorage)
        }
        
        private func highlightKeywords(in text: String, textStorage: NSTextStorage?) {
            let pattern = "\\b(" + SQLSyntax.keywords.joined(separator: "|") + ")\\b"
            highlightPattern(pattern, in: text, color: SQLSyntax.Colors.keyword, textStorage: textStorage, caseInsensitive: true)
        }
        
        private func highlightFunctions(in text: String, textStorage: NSTextStorage?) {
            let pattern = "\\b(" + SQLSyntax.functions.joined(separator: "|") + ")\\s*\\("
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let nsText = text as NSString
                let range = NSRange(location: 0, length: nsText.length)
                let matches = regex.matches(in: text, range: range)
                
                for match in matches {
                    // 只高亮函数名，不包括括号
                    var funcRange = match.range
                    funcRange.length -= 1  // 排除括号
                    
                    // 去掉末尾空格
                    let matchedText = nsText.substring(with: funcRange)
                    funcRange.length = matchedText.trimmingCharacters(in: .whitespaces).count
                    
                    textStorage?.addAttribute(.foregroundColor, value: SQLSyntax.Colors.function, range: funcRange)
                }
            }
        }
        
        private func highlightNumbers(in text: String, textStorage: NSTextStorage?) {
            let pattern = "\\b\\d+(\\.\\d+)?\\b"
            highlightPattern(pattern, in: text, color: SQLSyntax.Colors.number, textStorage: textStorage)
        }
        
        private func highlightPattern(_ pattern: String, in text: String, color: NSColor, textStorage: NSTextStorage?, caseInsensitive: Bool = false) {
            var options: NSRegularExpression.Options = []
            if caseInsensitive {
                options.insert(.caseInsensitive)
            }
            
            guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { return }
            let nsText = text as NSString
            let range = NSRange(location: 0, length: nsText.length)
            let matches = regex.matches(in: text, range: range)
            
            for match in matches {
                textStorage?.addAttribute(.foregroundColor, value: color, range: match.range)
            }
        }
        
        // MARK: - 自动补全
        private func triggerCompletion() {
            guard let textView = textView else { return }
            
            // 获取当前光标位置的单词
            let (word, range) = getCurrentWord(in: textView)
            currentWord = word
            currentWordRange = range
            
            // 如果单词太短，隐藏补全
            if word.count < 1 {
                hideCompletion()
                return
            }
            
            // 生成补全项
            completionItems = generateCompletions(for: word)
            
            if completionItems.isEmpty {
                hideCompletion()
                return
            }
            
            // 显示补全窗口
            showCompletion()
        }
        
        private func getCurrentWord(in textView: NSTextView) -> (String, NSRange) {
            let text = textView.string as NSString
            let cursorLocation = textView.selectedRange().location
            
            guard cursorLocation > 0 else { return ("", NSRange(location: 0, length: 0)) }
            
            var startIndex = cursorLocation - 1
            let validChars = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_"))
            
            // 向前查找单词开始位置
            while startIndex >= 0 {
                let char = text.character(at: startIndex)
                if let scalar = UnicodeScalar(char), validChars.contains(scalar) {
                    startIndex -= 1
                } else {
                    break
                }
            }
            startIndex += 1
            
            let length = cursorLocation - startIndex
            let range = NSRange(location: startIndex, length: length)
            let word = text.substring(with: range)
            
            return (word, range)
        }
        
        private func generateCompletions(for prefix: String) -> [CompletionItem] {
            var items: [CompletionItem] = []
            let lowercasedPrefix = prefix.lowercased()
            
            // 添加关键字补全
            for keyword in SQLSyntax.keywords {
                if keyword.lowercased().hasPrefix(lowercasedPrefix) {
                    items.append(CompletionItem(text: keyword, type: .keyword))
                }
            }
            
            // 添加函数补全
            for function in SQLSyntax.functions {
                if function.lowercased().hasPrefix(lowercasedPrefix) {
                    items.append(CompletionItem(text: function + "()", type: .function))
                }
            }
            
            // 添加表名补全
            for table in tables {
                if table.lowercased().hasPrefix(lowercasedPrefix) {
                    items.append(CompletionItem(text: table, type: .table))
                }
            }
            
            // 添加字段名补全
            for (tableName, cols) in columns {
                for col in cols {
                    if col.lowercased().hasPrefix(lowercasedPrefix) {
                        items.append(CompletionItem(text: col, type: .column, detail: tableName))
                    }
                }
            }
            
            // 按类型和名称排序：表名/字段名优先，然后是关键字和函数
            items.sort { a, b in
                let aIsSchema = a.type == .table || a.type == .column
                let bIsSchema = b.type == .table || b.type == .column
                if aIsSchema != bIsSchema {
                    return aIsSchema
                }
                return a.text.lowercased() < b.text.lowercased()
            }
            
            // 限制数量
            return Array(items.prefix(20))
        }
        
        private func showCompletion() {
            guard let textView = textView,
                  let window = textView.window,
                  !completionItems.isEmpty else {
                hideCompletion()
                return
            }
            
            // 计算补全窗口位置
            let cursorRect = textView.firstRect(forCharacterRange: currentWordRange, actualRange: nil)
            var screenPoint = cursorRect.origin
            screenPoint.y -= 4  // 稍微向下偏移
            
            // 创建或更新补全窗口
            if completionWindow == nil {
                completionWindow = CompletionWindow()
                completionWindow?.completionDelegate = self
            }
            
            completionWindow?.updateItems(completionItems)
            completionWindow?.showAt(point: screenPoint, relativeTo: window)
        }
        
        private func hideCompletion() {
            completionWindow?.hide()
        }
        
        // MARK: - CompletionDelegate
        func didSelectItem(_ item: CompletionItem) {
            insertCompletion(item)
        }
        
        private func insertSelectedCompletion() {
            guard let window = completionWindow,
                  let selectedItem = window.selectedItem else { return }
            insertCompletion(selectedItem)
        }
        
        private func insertCompletion(_ item: CompletionItem) {
            guard let textView = textView else { return }
            
            // 替换当前单词
            if currentWordRange.location != NSNotFound && currentWordRange.length > 0 {
                textView.replaceCharacters(in: currentWordRange, with: item.text)
            } else {
                textView.insertText(item.text, replacementRange: textView.selectedRange())
            }
            
            // 如果是函数，光标移动到括号内
            if item.type == .function && item.text.hasSuffix("()") {
                let newLocation = textView.selectedRange().location - 1
                textView.setSelectedRange(NSRange(location: newLocation, length: 0))
            }
            
            hideCompletion()
            
            // 触发高亮更新
            parent.text = textView.string
            applyHighlighting()
        }
    }
}

// MARK: - 补全代理协议
protocol CompletionDelegate: AnyObject {
    func didSelectItem(_ item: CompletionItem)
}

// MARK: - 自定义 NSTextView
class SQLEditorTextView: NSTextView {
    weak var completionDelegate: SQLTextView.Coordinator?
    
    override func keyDown(with event: NSEvent) {
        // 让 delegate 先处理
        super.keyDown(with: event)
    }
    
    // MARK: - 右键菜单
    override func menu(for event: NSEvent) -> NSMenu? {
        let menu = NSMenu(title: "SQL 操作")
        
        // 获取选中的文本
        let selectedRange = self.selectedRange()
        let hasSelection = selectedRange.length > 0
        
        // 执行选中的 SQL
        let executeItem = NSMenuItem(
            title: hasSelection ? "执行选中的 SQL" : "执行全部 SQL",
            action: #selector(executeSelectedSQL),
            keyEquivalent: ""
        )
        executeItem.target = self
        menu.addItem(executeItem)
        
        // EXPLAIN
        let explainItem = NSMenuItem(
            title: hasSelection ? "EXPLAIN 选中的 SQL" : "EXPLAIN 全部 SQL",
            action: #selector(explainSQL),
            keyEquivalent: ""
        )
        explainItem.target = self
        menu.addItem(explainItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // 格式化
        let formatItem = NSMenuItem(
            title: hasSelection ? "格式化选中内容" : "格式化全部 SQL",
            action: #selector(formatSelectedSQL),
            keyEquivalent: ""
        )
        formatItem.target = self
        menu.addItem(formatItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // 复制
        if hasSelection {
            let copyItem = NSMenuItem(
                title: "复制选中内容",
                action: #selector(copySelectedText),
                keyEquivalent: ""
            )
            copyItem.target = self
            menu.addItem(copyItem)
        }
        
        // 复制为带引号的字符串
        if hasSelection {
            let copyQuotedItem = NSMenuItem(
                title: "复制为字符串（带转义）",
                action: #selector(copyAsQuotedString),
                keyEquivalent: ""
            )
            copyQuotedItem.target = self
            menu.addItem(copyQuotedItem)
        }
        
        menu.addItem(NSMenuItem.separator())
        
        // 全选
        let selectAllItem = NSMenuItem(
            title: "全选",
            action: #selector(selectAllText),
            keyEquivalent: ""
        )
        selectAllItem.target = self
        menu.addItem(selectAllItem)
        
        return menu
    }
    
    @objc private func executeSelectedSQL() {
        completionDelegate?.executeQuery()
    }
    
    @objc private func explainSQL() {
        completionDelegate?.explainQuery()
    }
    
    @objc private func formatSelectedSQL() {
        completionDelegate?.formatSelectedOrAll()
    }
    
    @objc private func copySelectedText() {
        let selectedRange = self.selectedRange()
        if selectedRange.length > 0 {
            let text = (self.string as NSString).substring(with: selectedRange)
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
        }
    }
    
    @objc private func copyAsQuotedString() {
        let selectedRange = self.selectedRange()
        if selectedRange.length > 0 {
            let text = (self.string as NSString).substring(with: selectedRange)
            // 转义并添加引号
            let escaped = text
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "\"", with: "\\\"")
                .replacingOccurrences(of: "\n", with: "\\n")
                .replacingOccurrences(of: "\t", with: "\\t")
            let quoted = "\"\(escaped)\""
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(quoted, forType: .string)
        }
    }
    
    @objc private func selectAllText() {
        self.selectAll(nil)
    }
}
