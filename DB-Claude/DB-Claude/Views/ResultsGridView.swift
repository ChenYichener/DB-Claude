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
            self.dataHash = dataRows.count
        } else if let first = results.first {
            let cols = first.keys.sorted()
            self.columns = cols
            self.rowData = results.map { row in cols.map { col in row[col] } }
            self.dataHash = results.count
        } else {
            self.columns = []
            self.rowData = []
            self.dataHash = 0
        }
    }
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = false
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = true
        scrollView.backgroundColor = NSColor.windowBackgroundColor
        
        let tableView = EditableTableView()
        tableView.style = .plain
        tableView.allowsColumnReordering = false
        tableView.allowsColumnResizing = true
        tableView.allowsMultipleSelection = false
        tableView.rowHeight = 24
        tableView.intercellSpacing = NSSize(width: 1, height: 1)
        tableView.gridStyleMask = [.solidHorizontalGridLineMask, .solidVerticalGridLineMask]
        tableView.gridColor = NSColor.separatorColor.withAlphaComponent(0.15)
        tableView.backgroundColor = NSColor.windowBackgroundColor
        tableView.usesAlternatingRowBackgroundColors = true
        tableView.columnAutoresizingStyle = .noColumnAutoresizing
        
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
        
        return scrollView
    }
    
    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let tableView = scrollView.documentView as? EditableTableView else { return }
        
        let coordinator = context.coordinator
        let needsReload = coordinator.dataHash != dataHash || coordinator.columns != columns
        
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
        
        // 更新编辑模式
        tableView.isEditingEnabled = isEditable
        
        // 检查列是否变化
        let existingColumns = tableView.tableColumns.map { $0.identifier.rawValue }
        if existingColumns != columns {
            tableView.tableColumns.forEach { tableView.removeTableColumn($0) }
            setupColumns(tableView: tableView, coordinator: coordinator)
        }
        
        // 更新排序指示器
        updateSortIndicators(tableView: tableView)
        
        if needsReload {
            tableView.reloadData()
        }
    }
    
    private func setupColumns(tableView: NSTableView, coordinator: Coordinator) {
        for (index, columnName) in columns.enumerated() {
            let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(columnName))
            column.title = columnName
            column.width = 120
            column.minWidth = 50
            column.maxWidth = 500
            column.resizingMask = .userResizingMask
            column.isEditable = isEditable
            column.sortDescriptorPrototype = NSSortDescriptor(key: columnName, ascending: true)
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
    class Coordinator: NSObject, NSTableViewDelegate, NSTableViewDataSource {
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
        
        // 缓存
        private let normalFont = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        private let nullFont: NSFont
        private let normalColor = NSColor.labelColor
        private let nullColor = NSColor.tertiaryLabelColor
        private let editedColor = NSColor.systemOrange
        
        // 编辑跟踪
        var editedCells: [String: String?] = [:]  // "row_col" -> newValue
        
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
            
            let descriptor = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular).fontDescriptor.withSymbolicTraits(.italic)
            self.nullFont = NSFont(descriptor: descriptor, size: 12) ?? NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
            
            super.init()
            
            for (index, col) in columns.enumerated() {
                columnIndexMap[col] = index
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
                
                // 设置 target/action 来处理编辑完成事件
                textField.target = self
                textField.action = #selector(textFieldDidEndEditing(_:))
                
                // 添加到 cellView 并设置约束
                cellView.addSubview(textField)
                cellView.textField = textField
                
                textField.translatesAutoresizingMaskIntoConstraints = false
                NSLayoutConstraint.activate([
                    textField.leadingAnchor.constraint(equalTo: cellView.leadingAnchor, constant: 4),
                    textField.trailingAnchor.constraint(equalTo: cellView.trailingAnchor, constant: -4),
                    textField.centerYAnchor.constraint(equalTo: cellView.centerYAnchor)
                ])
            }
            
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
        
        // 编辑完成时的回调（通过 target/action 触发）
        @objc func textFieldDidEndEditing(_ sender: NSTextField) {
            guard let columnName = sender.cell?.representedObject as? String,
                  let columnIndex = columnIndexMap[columnName] else { return }
            
            let row = sender.tag
            guard row >= 0 && row < rowData.count else { return }
            
            let oldValue = rowData[row][columnIndex]
            var newValue: String? = sender.stringValue
            
            // 如果输入 "NULL" 或空字符串，视为 NULL
            if newValue == "NULL" || newValue?.isEmpty == true {
                newValue = nil
            }
            
            // 只在值真正变化时记录
            if oldValue != newValue {
                let editKey = "\(row)_\(columnIndex)"
                editedCells[editKey] = newValue
                
                let edit = CellEdit(row: row, column: columnName, oldValue: oldValue, newValue: newValue)
                onCellEdit?(edit)
                
                // 更新颜色显示
                sender.textColor = editedColor
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
    
    override func noteNumberOfRowsChanged() {
        NSAnimationContext.beginGrouping()
        NSAnimationContext.current.duration = 0
        super.noteNumberOfRowsChanged()
        NSAnimationContext.endGrouping()
    }
    
    override var isOpaque: Bool { true }
    
    // 关键：允许 NSTextField 成为第一响应者，这样双击才能进入编辑模式
    override func validateProposedFirstResponder(_ responder: NSResponder, for event: NSEvent?) -> Bool {
        // 如果编辑已启用且响应者是 NSTextField，允许它成为第一响应者
        if isEditingEnabled && responder is NSTextField {
            return true
        }
        return super.validateProposedFirstResponder(responder, for: event)
    }
    
    // 双击开始编辑指定单元格
    override func mouseDown(with event: NSEvent) {
        let localPoint = convert(event.locationInWindow, from: nil)
        let clickedRow = row(at: localPoint)
        let clickedColumn = column(at: localPoint)
        
        // 先执行默认的选中行为
        super.mouseDown(with: event)
        
        // 如果是双击且启用编辑，开始编辑单元格
        if event.clickCount == 2 && isEditingEnabled && clickedRow >= 0 && clickedColumn >= 0 {
            // 延迟一下确保选中状态更新
            DispatchQueue.main.async { [weak self] in
                self?.editCell(row: clickedRow, column: clickedColumn)
            }
        }
    }
    
    // 编辑指定单元格
    func editCell(row: Int, column: Int) {
        guard row >= 0 && column >= 0 && column < tableColumns.count else { return }
        
        // 获取单元格视图（现在是 NSTableCellView）
        if let tableCellView = view(atColumn: column, row: row, makeIfNecessary: false) as? NSTableCellView,
           let textField = tableCellView.textField {
            // 选中该行
            selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
            
            // 确保 textField 可以成为第一响应者
            if textField.acceptsFirstResponder {
                // 开始编辑
                window?.makeFirstResponder(textField)
                
                // 选中所有文字
                if let editor = textField.currentEditor() {
                    editor.selectAll(nil)
                }
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
