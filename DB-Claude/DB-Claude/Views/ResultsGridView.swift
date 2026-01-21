import SwiftUI
import AppKit

// MARK: - 排序方向枚举
enum SortOrder: Equatable {
    case ascending
    case descending
    
    var icon: String {
        switch self {
        case .ascending: return "chevron.up"
        case .descending: return "chevron.down"
        }
    }
    
    var sqlKeyword: String {
        switch self {
        case .ascending: return "ASC"
        case .descending: return "DESC"
        }
    }
    
    mutating func toggle() {
        self = self == .ascending ? .descending : .ascending
    }
}

// MARK: - 单元格修改记录
struct CellEdit: Equatable {
    let row: Int
    let column: String
    let oldValue: String?
    let newValue: String?
}

// MARK: - 可编辑数据表格
struct EditableResultsGridView: NSViewRepresentable {
    let results: [[String: String]]
    let tableName: String
    var sortColumn: String?
    var sortOrder: SortOrder
    var isEditable: Bool
    var onSort: ((String) -> Void)?
    var onCellEdit: ((CellEdit) -> Void)?
    var onRowSelect: ((Int?) -> Void)?
    var onCopySQL: ((String) -> Void)?
    
    // 预处理后的数据
    private let columns: [String]
    private let rowData: [[String?]]
    private let dataHash: Int
    
    init(results: [[String: String]], 
         tableName: String,
         sortColumn: String? = nil, 
         sortOrder: SortOrder = .ascending, 
         isEditable: Bool = false,
         onSort: ((String) -> Void)? = nil,
         onCellEdit: ((CellEdit) -> Void)? = nil,
         onRowSelect: ((Int?) -> Void)? = nil,
         onCopySQL: ((String) -> Void)? = nil) {
        self.results = results
        self.tableName = tableName
        self.sortColumn = sortColumn
        self.sortOrder = sortOrder
        self.isEditable = isEditable
        self.onSort = onSort
        self.onCellEdit = onCellEdit
        self.onRowSelect = onRowSelect
        self.onCopySQL = onCopySQL
        
        // 预处理数据
        if let first = results.first, let columnsStr = first["__columns__"] {
            let cols = columnsStr.split(separator: ",").map { String($0) }
            self.columns = cols
            let dataRows = Array(results.dropFirst())
            self.rowData = dataRows.map { row in cols.map { col in row[col] } }
            // 使用更可靠的 hash：基于数据内容而不仅仅是行数
            self.dataHash = Self.computeDataHash(rowData: self.rowData)
        } else if let first = results.first {
            let cols = first.keys.sorted()
            self.columns = cols
            self.rowData = results.map { row in cols.map { col in row[col] } }
            self.dataHash = Self.computeDataHash(rowData: self.rowData)
        } else {
            self.columns = []
            self.rowData = []
            self.dataHash = 0
        }
    }
    
    /// 计算数据的 hash 值，用于检测数据是否变化
    private static func computeDataHash(rowData: [[String?]]) -> Int {
        var hasher = Hasher()
        hasher.combine(rowData.count)
        // 取前 10 行和后 10 行的数据计算 hash，避免大数据集时性能问题
        let sampleRows = Array(rowData.prefix(10)) + Array(rowData.suffix(10))
        for row in sampleRows {
            for value in row {
                hasher.combine(value)
            }
        }
        return hasher.finalize()
    }
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true  // 自动隐藏滚动条，更简洁
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = true
        scrollView.backgroundColor = NSColor.textBackgroundColor

        let tableView = EditableTableView()
        tableView.style = .plain
        tableView.allowsColumnReordering = false
        tableView.allowsColumnResizing = true
        tableView.allowsMultipleSelection = false
        tableView.rowHeight = 32  // 适中的行高
        tableView.intercellSpacing = NSSize(width: 0, height: 1)  // 只有水平间距
        tableView.gridStyleMask = [.solidHorizontalGridLineMask]  // 只显示水平分隔线
        tableView.gridColor = NSColor.separatorColor.withAlphaComponent(0.15)
        tableView.backgroundColor = NSColor.textBackgroundColor
        tableView.usesAlternatingRowBackgroundColors = false  // 关闭交替颜色
        tableView.columnAutoresizingStyle = .noColumnAutoresizing
        tableView.selectionHighlightStyle = .regular  // 使用系统选中样式

        // 设置编辑模式
        tableView.isEditingEnabled = isEditable

        // 设置代理和数据源
        let coordinator = context.coordinator
        tableView.delegate = coordinator
        tableView.dataSource = coordinator
        coordinator.tableView = tableView

        // 配置列
        setupColumns(tableView: tableView, coordinator: coordinator)

        // 配置右键菜单
        tableView.menu = createContextMenu(coordinator: coordinator)

        scrollView.documentView = tableView
        
        // 初始加载数据
        tableView.reloadData()
        print("[EditableGrid] makeNSView: 初始化完成, columns=\(columns.count), rows=\(rowData.count)")

        return scrollView
    }
    
    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let tableView = scrollView.documentView as? EditableTableView else { return }
        
        let coordinator = context.coordinator
        let needsReload = coordinator.dataHash != dataHash || coordinator.columns != columns
        let editModeChanged = coordinator.isEditable != isEditable
        
        // 检查表格是否正在编辑（只检查表格内部的编辑状态）
        let isCurrentlyEditing: Bool = {
            guard let firstResponder = tableView.window?.firstResponder else { return false }
            // 检查 firstResponder 是否是表格内部的 field editor 或 text field
            if let textView = firstResponder as? NSTextView,
               let delegate = textView.delegate as? NSTextField,
               delegate.superview?.superview === tableView {
                return true
            }
            if let textField = firstResponder as? NSTextField,
               textField.superview?.superview === tableView {
                return true
            }
            return false
        }()
        
        print("[EditableGrid] updateNSView: needsReload=\(needsReload), columns=\(columns.count), rows=\(rowData.count), hash=\(dataHash), oldHash=\(coordinator.dataHash)")
        
        // 更新数据
        coordinator.columns = columns
        coordinator.rowData = rowData
        coordinator.dataHash = dataHash
        coordinator.sortColumn = sortColumn
        coordinator.sortOrder = sortOrder
        coordinator.isEditable = isEditable
        coordinator.tableName = tableName
        coordinator.onSort = onSort
        coordinator.onCellEdit = onCellEdit
        coordinator.onRowSelect = onRowSelect
        coordinator.onCopySQL = onCopySQL
        
        // 关键：更新 columnIndexMap
        coordinator.columnIndexMap.removeAll()
        for (index, col) in columns.enumerated() {
            coordinator.columnIndexMap[col] = index
        }
        
        // 更新编辑模式
        tableView.isEditingEnabled = isEditable
        
        // 关键修复：当编辑模式变化时，更新所有可见单元格的 isEditable 属性
        if editModeChanged {
            print("[EditableGrid] updateNSView: 编辑模式变化，更新所有可见单元格")
            updateAllVisibleCellsEditability(tableView: tableView, isEditable: isEditable)
        }
        
        // 检查列是否变化
        let existingColumns = tableView.tableColumns.map { $0.identifier.rawValue }
        if existingColumns != columns {
            tableView.tableColumns.forEach { tableView.removeTableColumn($0) }
            setupColumns(tableView: tableView, coordinator: coordinator)
        }
        
        // 更新排序指示器
        updateSortIndicators(tableView: tableView)
        
        // 关键修复：如果正在编辑，不要 reloadData，否则会导致编辑被中断
        if needsReload && !isCurrentlyEditing {
            print("[EditableGrid] updateNSView: 执行 reloadData")
            tableView.reloadData()
        } else if needsReload && isCurrentlyEditing {
            print("[EditableGrid] updateNSView: 跳过 reloadData（正在编辑中）")
        }
    }
    
    // 更新所有可见单元格的编辑状态
    private func updateAllVisibleCellsEditability(tableView: NSTableView, isEditable: Bool) {
        let visibleRows = tableView.rows(in: tableView.visibleRect)
        print("[EditableGrid] 更新可见单元格: rows=\(visibleRows.location)..<\(visibleRows.location + visibleRows.length), isEditable=\(isEditable)")
        
        for row in visibleRows.location..<(visibleRows.location + visibleRows.length) {
            for col in 0..<tableView.numberOfColumns {
                if let cellView = tableView.view(atColumn: col, row: row, makeIfNecessary: false) as? NSTableCellView,
                   let textField = cellView.textField {
                    textField.isEditable = isEditable
                }
            }
        }
    }
    
    private func setupColumns(tableView: NSTableView, coordinator: Coordinator) {
        for (index, columnName) in columns.enumerated() {
            let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(columnName))
            column.title = columnName
            column.width = 120  // 紧凑的默认列宽
            column.minWidth = 50
            column.maxWidth = 500
            column.resizingMask = .userResizingMask
            column.isEditable = isEditable
            column.sortDescriptorPrototype = NSSortDescriptor(key: columnName, ascending: true)

            // 现代表头样式
            let headerCell = NSTableHeaderCell(textCell: columnName)
            headerCell.font = NSFont.systemFont(ofSize: 11, weight: .medium)
            column.headerCell = headerCell

            coordinator.columnIndexMap[columnName] = index
            tableView.addTableColumn(column)
        }
    }
    
    private func updateSortIndicators(tableView: NSTableView) {
        for column in tableView.tableColumns {
            let columnName = column.identifier.rawValue
            if columnName == sortColumn {
                let image = NSImage(systemSymbolName: sortOrder == .ascending ? "chevron.up" : "chevron.down", accessibilityDescription: nil)
                tableView.setIndicatorImage(image, in: column)
            } else {
                tableView.setIndicatorImage(nil, in: column)
            }
        }
    }
    
    private func createContextMenu(coordinator: Coordinator) -> NSMenu {
        let menu = NSMenu()
        
        let copyInsert = NSMenuItem(title: "复制为 INSERT", action: #selector(Coordinator.copyAsInsert), keyEquivalent: "")
        copyInsert.target = coordinator
        menu.addItem(copyInsert)
        
        let copyUpdate = NSMenuItem(title: "复制为 UPDATE", action: #selector(Coordinator.copyAsUpdate), keyEquivalent: "")
        copyUpdate.target = coordinator
        menu.addItem(copyUpdate)
        
        let copyDelete = NSMenuItem(title: "复制为 DELETE", action: #selector(Coordinator.copyAsDelete), keyEquivalent: "")
        copyDelete.target = coordinator
        menu.addItem(copyDelete)
        
        menu.addItem(NSMenuItem.separator())
        
        let copyRow = NSMenuItem(title: "复制行数据", action: #selector(Coordinator.copyRowData), keyEquivalent: "c")
        copyRow.target = coordinator
        menu.addItem(copyRow)
        
        return menu
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(columns: columns, rowData: rowData, dataHash: dataHash, tableName: tableName, 
                   sortColumn: sortColumn, sortOrder: sortOrder, isEditable: isEditable,
                   onSort: onSort, onCellEdit: onCellEdit, onRowSelect: onRowSelect, onCopySQL: onCopySQL)
    }
    
    // MARK: - Coordinator
    class Coordinator: NSObject, NSTableViewDelegate, NSTableViewDataSource, NSTextFieldDelegate {
        var columns: [String]
        var rowData: [[String?]]
        var dataHash: Int
        var tableName: String
        var sortColumn: String?
        var sortOrder: SortOrder
        var isEditable: Bool
        var onSort: ((String) -> Void)?
        var onCellEdit: ((CellEdit) -> Void)?
        var onRowSelect: ((Int?) -> Void)?
        var onCopySQL: ((String) -> Void)?
        var columnIndexMap: [String: Int] = [:]
        weak var tableView: NSTableView?
        
        // 缓存 - 使用系统字体，更现代简洁
        private let normalFont = NSFont.systemFont(ofSize: 12, weight: .regular)
        private let nullFont: NSFont
        private let normalColor = NSColor.labelColor
        private let nullColor = NSColor.placeholderTextColor
        private let editedColor = NSColor.systemBlue
        
        // 编辑跟踪
        var editedCells: [String: String?] = [:]  // "row_col" -> newValue
        
        // 调试标志
        private let debugEnabled = true
        
        init(columns: [String], rowData: [[String?]], dataHash: Int, tableName: String,
             sortColumn: String?, sortOrder: SortOrder, isEditable: Bool,
             onSort: ((String) -> Void)?, onCellEdit: ((CellEdit) -> Void)?,
             onRowSelect: ((Int?) -> Void)?, onCopySQL: ((String) -> Void)?) {
            self.columns = columns
            self.rowData = rowData
            self.dataHash = dataHash
            self.tableName = tableName
            self.sortColumn = sortColumn
            self.sortOrder = sortOrder
            self.isEditable = isEditable
            self.onSort = onSort
            self.onCellEdit = onCellEdit
            self.onRowSelect = onRowSelect
            self.onCopySQL = onCopySQL
            
            // NULL 值使用斜体系统字体
            let descriptor = NSFont.systemFont(ofSize: 11, weight: .regular).fontDescriptor.withSymbolicTraits(.italic)
            self.nullFont = NSFont(descriptor: descriptor, size: 11) ?? NSFont.systemFont(ofSize: 11, weight: .light)
            
            super.init()
            
            for (index, col) in columns.enumerated() {
                columnIndexMap[col] = index
            }
            
            debugLog("Coordinator 初始化完成, isEditable=\(isEditable), columns=\(columns)")
        }
        
        private func debugLog(_ message: String) {
            if debugEnabled {
                print("[EditableGrid] \(message)")
            }
        }
        
        func numberOfRows(in tableView: NSTableView) -> Int {
            rowData.count
        }
        
        func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
            guard let tableColumn = tableColumn else { return nil }
            
            let columnName = tableColumn.identifier.rawValue
            guard let columnIndex = columnIndexMap[columnName] else { return nil }
            
            let cellId = NSUserInterfaceItemIdentifier("EditableCell_\(columnName)")
            
            // 使用 NSTableCellView 作为容器（这是 AppKit 的标准做法）
            let cellView: NSTableCellView
            let textField: NSTextField
            
            if let reusedCell = tableView.makeView(withIdentifier: cellId, owner: self) as? NSTableCellView,
               let existingTextField = reusedCell.textField {
                cellView = reusedCell
                textField = existingTextField
            } else {
                // 创建新的 NSTableCellView
                cellView = NSTableCellView()
                cellView.identifier = cellId
                
                // 创建 NSTextField
                textField = NSTextField()
                textField.isBezeled = false
                textField.drawsBackground = false
                textField.lineBreakMode = .byTruncatingTail
                textField.cell?.truncatesLastVisibleLine = true
                textField.focusRingType = .exterior
                
                // 添加到 cellView 并设置约束
                cellView.addSubview(textField)
                cellView.textField = textField
                
                textField.translatesAutoresizingMaskIntoConstraints = false
                NSLayoutConstraint.activate([
                    textField.leadingAnchor.constraint(equalTo: cellView.leadingAnchor, constant: 8),
                    textField.trailingAnchor.constraint(equalTo: cellView.trailingAnchor, constant: -8),
                    textField.centerYAnchor.constraint(equalTo: cellView.centerYAnchor)
                ])
            }
            
            // 关键：设置 delegate 来捕获所有编辑结束事件（不仅仅是按 Enter）
            // NSTextFieldDelegate 的 controlTextDidEndEditing 会在失去焦点时触发
            textField.delegate = self
            
            // 同时保留 target/action 作为备用（按 Enter 时触发）
            textField.target = self
            textField.action = #selector(textFieldActionTriggered(_:))
            
            // 设置是否可编辑和可选择
            textField.isEditable = isEditable
            textField.isSelectable = true
            
            // 检查是否有编辑过的值
            let editKey = "\(row)_\(columnIndex)"
            let value: String?
            if let editedValue = editedCells[editKey] {
                value = editedValue
                textField.textColor = editedColor  // 已编辑的单元格用橙色
            } else {
                value = rowData[row][columnIndex]
                textField.textColor = value == nil ? nullColor : normalColor
            }
            
            if let value = value {
                textField.stringValue = value
                textField.font = normalFont
            } else {
                textField.stringValue = "NULL"
                textField.font = nullFont
            }
            
            // 存储行列信息用于编辑回调
            textField.tag = row
            // 使用 cell 的 representedObject 存储列名
            textField.cell?.representedObject = columnName
            
            return cellView
        }
        
        // MARK: - NSTextFieldDelegate 方法
        
        // 编辑开始时的回调（用于调试）
        func controlTextDidBeginEditing(_ obj: Notification) {
            guard let textField = obj.object as? NSTextField else { return }
            let columnName = textField.cell?.representedObject as? String ?? "unknown"
        }
        
        // 编辑结束时的回调（NSTextFieldDelegate 方法，失去焦点时触发）
        func controlTextDidEndEditing(_ obj: Notification) {
            guard let textField = obj.object as? NSTextField else {
                debugLog("controlTextDidEndEditing: 无法获取 textField")
                return
            }
            
            processEditEnd(textField: textField)
        }
        
        // 按 Enter 键时的回调（通过 target/action 触发）
        @objc func textFieldActionTriggered(_ sender: NSTextField) {
            // 注意：按 Enter 后会自动触发 controlTextDidEndEditing，所以这里不需要重复处理
            // 但为了安全，我们可以标记一下已经处理过
        }
        
        // 统一处理编辑结束逻辑
        private func processEditEnd(textField: NSTextField) {
            guard let columnName = textField.cell?.representedObject as? String,
                  let columnIndex = columnIndexMap[columnName] else {
                debugLog("processEditEnd: 无法获取列信息, representedObject=\(String(describing: textField.cell?.representedObject))")
                return
            }
            
            let row = textField.tag
            guard row >= 0 && row < rowData.count else {
                debugLog("processEditEnd: row 超出范围, row=\(row), count=\(rowData.count)")
                return
            }
            
            let oldValue = rowData[row][columnIndex]
            var newValue: String? = textField.stringValue
            
            // 如果输入 "NULL" 或空字符串，视为 NULL
            if newValue == "NULL" || newValue?.isEmpty == true {
                newValue = nil
            }
            
            debugLog("processEditEnd: row=\(row), col=\(columnName), oldValue='\(oldValue ?? "nil")', newValue='\(newValue ?? "nil")'")
            
            // 只在值真正变化时记录
            if oldValue != newValue {
                let editKey = "\(row)_\(columnIndex)"
                editedCells[editKey] = newValue
                
                let edit = CellEdit(row: row, column: columnName, oldValue: oldValue, newValue: newValue)
                debugLog(">>> 记录编辑: \(edit)")
                onCellEdit?(edit)
                
                // 更新颜色显示
                textField.textColor = editedColor
            } else {
                debugLog("processEditEnd: 值未变化，不记录")
            }
        }
        
        // 选中行变化
        func tableViewSelectionDidChange(_ notification: Notification) {
            guard let tableView = notification.object as? NSTableView else { return }
            let selectedRow = tableView.selectedRow
            onRowSelect?(selectedRow >= 0 ? selectedRow : nil)
        }
        
        // 排序变化
        func tableView(_ tableView: NSTableView, sortDescriptorsDidChange oldDescriptors: [NSSortDescriptor]) {
            guard let sortDescriptor = tableView.sortDescriptors.first,
                  let key = sortDescriptor.key else { return }
            onSort?(key)
        }
        
        // MARK: - 右键菜单操作
        @objc func copyAsInsert() {
            guard let tableView = tableView else { return }
            let selectedRow = tableView.selectedRow
            guard selectedRow >= 0 else { return }
            
            let values = columns.map { col -> String in
                guard let idx = columnIndexMap[col] else { return "NULL" }
                if let value = rowData[selectedRow][idx] {
                    return "'\(value.replacingOccurrences(of: "'", with: "''"))'"
                }
                return "NULL"
            }
            
            let sql = "INSERT INTO \(tableName) (\(columns.joined(separator: ", "))) VALUES (\(values.joined(separator: ", ")));"
            copyToClipboard(sql)
            onCopySQL?(sql)
        }
        
        @objc func copyAsUpdate() {
            guard let tableView = tableView else { return }
            let selectedRow = tableView.selectedRow
            guard selectedRow >= 0 else { return }
            
            let setClauses = columns.map { col -> String in
                guard let idx = columnIndexMap[col] else { return "\(col) = NULL" }
                if let value = rowData[selectedRow][idx] {
                    return "\(col) = '\(value.replacingOccurrences(of: "'", with: "''"))'"
                }
                return "\(col) = NULL"
            }
            
            // 使用第一列作为 WHERE 条件（通常是主键）
            let whereClause: String
            if let firstCol = columns.first, let idx = columnIndexMap[firstCol], let value = rowData[selectedRow][idx] {
                whereClause = "\(firstCol) = '\(value.replacingOccurrences(of: "'", with: "''"))'"
            } else {
                whereClause = "1 = 1 /* 请修改 WHERE 条件 */"
            }
            
            let sql = "UPDATE \(tableName) SET \(setClauses.joined(separator: ", ")) WHERE \(whereClause);"
            copyToClipboard(sql)
            onCopySQL?(sql)
        }
        
        @objc func copyAsDelete() {
            guard let tableView = tableView else { return }
            let selectedRow = tableView.selectedRow
            guard selectedRow >= 0 else { return }
            
            // 使用第一列作为 WHERE 条件
            let whereClause: String
            if let firstCol = columns.first, let idx = columnIndexMap[firstCol], let value = rowData[selectedRow][idx] {
                whereClause = "\(firstCol) = '\(value.replacingOccurrences(of: "'", with: "''"))'"
            } else {
                whereClause = "1 = 1 /* 请修改 WHERE 条件 */"
            }
            
            let sql = "DELETE FROM \(tableName) WHERE \(whereClause);"
            copyToClipboard(sql)
            onCopySQL?(sql)
        }
        
        @objc func copyRowData() {
            guard let tableView = tableView else { return }
            let selectedRow = tableView.selectedRow
            guard selectedRow >= 0 else { return }
            
            let values = columns.map { col -> String in
                guard let idx = columnIndexMap[col] else { return "NULL" }
                return rowData[selectedRow][idx] ?? "NULL"
            }
            
            let text = values.joined(separator: "\t")
            copyToClipboard(text)
        }
        
        private func copyToClipboard(_ text: String) {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(text, forType: .string)
        }
    }
}

// MARK: - 可编辑的 NSTableView 子类
class EditableTableView: NSTableView {
    
    // 是否允许编辑
    var isEditingEnabled: Bool = false
    
    // 调试标志
    private let debugEnabled = true
    
    private func debugLog(_ message: String) {
        if debugEnabled {
            print("[EditableTableView] \(message)")
        }
    }
    
    override func noteNumberOfRowsChanged() {
        NSAnimationContext.beginGrouping()
        NSAnimationContext.current.duration = 0
        super.noteNumberOfRowsChanged()
        NSAnimationContext.endGrouping()
    }
    
    override var isOpaque: Bool { true }
    
    // 关键：允许 NSTextField 成为第一响应者，这样双击才能进入编辑模式
    override func validateProposedFirstResponder(_ responder: NSResponder, for event: NSEvent?) -> Bool {
        let isTextField = responder is NSTextField
        let result: Bool
        
        // 如果编辑已启用且响应者是 NSTextField，允许它成为第一响应者
        if isEditingEnabled && isTextField {
            result = true
        } else {
            result = super.validateProposedFirstResponder(responder, for: event)
        }
        
        // 只在 NSTextField 且编辑模式下打印日志（大幅减少噪音）
        // 注释掉这行日志，因为太多了
        // if isEditingEnabled && isTextField {
        //     debugLog("validateProposedFirstResponder: isTextField=\(isTextField), result=\(result)")
        // }
        return result
    }
    
    // 处理鼠标点击事件
    override func mouseDown(with event: NSEvent) {
        let localPoint = convert(event.locationInWindow, from: nil)
        let clickedRow = row(at: localPoint)
        let clickedColumn = column(at: localPoint)
        
        debugLog(">>> mouseDown: clickCount=\(event.clickCount), row=\(clickedRow), col=\(clickedColumn), isEditingEnabled=\(isEditingEnabled)")
        
        // 先执行默认的选中行为
        super.mouseDown(with: event)
        
        // 如果启用编辑且点击了有效单元格
        if isEditingEnabled && clickedRow >= 0 && clickedColumn >= 0 {
            if event.clickCount == 2 {
                // 双击：立即进入编辑模式
                debugLog(">>> 双击检测到，准备编辑单元格")
                DispatchQueue.main.async { [weak self] in
                    self?.editCell(row: clickedRow, column: clickedColumn)
                }
            } else if event.clickCount == 1 {
                // 单击：延迟进入编辑模式（给双击一个检测窗口）
                debugLog(">>> 单击检测到，延迟进入编辑")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                    guard let self = self else { return }
                    // 检查是否仍然选中同一行
                    if self.selectedRow == clickedRow {
                        self.editCell(row: clickedRow, column: clickedColumn)
                    }
                }
            }
        }
    }
    
    // 编辑指定单元格
    func editCell(row: Int, column: Int) {
        debugLog(">>> editCell 开始: row=\(row), column=\(column)")
        
        guard row >= 0 && column >= 0 && column < tableColumns.count else {
            debugLog("editCell: 无效的 row/column")
            return
        }
        
        // 获取单元格视图（现在是 NSTableCellView）
        if let tableCellView = view(atColumn: column, row: row, makeIfNecessary: false) as? NSTableCellView,
           let textField = tableCellView.textField {
            debugLog("editCell: 找到 textField")
            debugLog("  - isEditable=\(textField.isEditable)")
            debugLog("  - isSelectable=\(textField.isSelectable)")
            debugLog("  - acceptsFirstResponder=\(textField.acceptsFirstResponder)")
            debugLog("  - stringValue='\(textField.stringValue)'")
            
            // 确保 textField 可编辑
            if !textField.isEditable {
                debugLog("editCell: textField 不可编辑！强制设置为可编辑")
                textField.isEditable = true
            }
            
            // 选中该行
            selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
            
            // 确保 textField 可以成为第一响应者
            if textField.acceptsFirstResponder {
                debugLog("editCell: 尝试让 textField 成为 firstResponder")
                
                // 方法1：使用 window.makeFirstResponder
                let success = window?.makeFirstResponder(textField) ?? false
                debugLog("editCell: makeFirstResponder 结果=\(success)")
                
                // 等待一下让 field editor 创建
                DispatchQueue.main.async { [weak textField] in
                    guard let textField = textField else { return }
                    
                    // 检查 field editor 是否已创建
                    if let editor = textField.currentEditor() {
                        print("[EditableTableView] editCell: field editor 已创建，选中所有文字")
                        editor.selectAll(nil)
                    } else {
                        print("[EditableTableView] editCell: field editor 未创建，尝试 selectText")
                        // 方法2：尝试使用 selectText 来触发编辑
                        textField.selectText(nil)
                        
                        // 再次检查
                        if let editor = textField.currentEditor() {
                            print("[EditableTableView] editCell: selectText 后 field editor 已创建")
                            editor.selectAll(nil)
                        } else {
                            print("[EditableTableView] editCell: selectText 后仍然没有 field editor")
                        }
                    }
                }
            } else {
                debugLog("editCell: textField 不接受 firstResponder")
            }
        } else {
            debugLog("editCell: 未找到 tableCellView 或 textField")
            if let view = view(atColumn: column, row: row, makeIfNecessary: false) {
                debugLog("editCell: 找到的 view 类型是 \(type(of: view))")
            }
        }
    }
}

// MARK: - 只读结果表格（向后兼容）
typealias ResultsGridView = EditableResultsGridView

// MARK: - 高性能 NSTableView 子类
class HighPerformanceTableView: NSTableView {
    // 禁用不必要的动画
    override func noteNumberOfRowsChanged() {
        NSAnimationContext.beginGrouping()
        NSAnimationContext.current.duration = 0
        super.noteNumberOfRowsChanged()
        NSAnimationContext.endGrouping()
    }
    
    // 优化绘制
    override var isOpaque: Bool { true }
    
    // 禁用实时调整大小时的重绘
    override func viewWillStartLiveResize() {
        super.viewWillStartLiveResize()
        layer?.drawsAsynchronously = true
    }
    
    override func viewDidEndLiveResize() {
        super.viewDidEndLiveResize()
        layer?.drawsAsynchronously = false
    }
}

// MARK: - 空状态视图
struct EmptyResultsView: View {
    var body: some View {
        VStack(spacing: AppSpacing.md) {
            Image(systemName: "table")
                .font(.system(size: 32, weight: .light))
                .foregroundColor(AppColors.tertiaryText)
            
            Text("无查询结果")
                .font(.system(size: 14))
                .foregroundColor(AppColors.secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.background)
    }
}
