import SwiftUI
import AppKit

// MARK: - 筛选操作符
enum FilterOperator: String, CaseIterable {
    case equal = "="
    case notEqual = "!="
    case greaterThan = ">"
    case lessThan = "<"
    case greaterOrEqual = ">="
    case lessOrEqual = "<="
    case like = "LIKE"
    case isNull = "IS NULL"
    case isNotNull = "IS NOT NULL"
    
    var displayName: String {
        switch self {
        case .equal: return "等于 (=)"
        case .notEqual: return "不等于 (!=)"
        case .greaterThan: return "大于 (>)"
        case .lessThan: return "小于 (<)"
        case .greaterOrEqual: return "大于等于 (>=)"
        case .lessOrEqual: return "小于等于 (<=)"
        case .like: return "包含 (LIKE)"
        case .isNull: return "为空 (NULL)"
        case .isNotNull: return "不为空 (NOT NULL)"
        }
    }
    
    var needsValue: Bool {
        self != .isNull && self != .isNotNull
    }
}

// MARK: - 筛选条件
struct FilterCondition: Identifiable, Equatable {
    let id = UUID()
    var field: String
    var op: FilterOperator
    var value: String
    
    func toSQL() -> String? {
        guard !field.isEmpty else { return nil }
        
        switch op {
        case .isNull:
            return "\(field) IS NULL"
        case .isNotNull:
            return "\(field) IS NOT NULL"
        case .like:
            guard !value.isEmpty else { return nil }
            return "\(field) LIKE '%\(value.replacingOccurrences(of: "'", with: "''"))%'"
        default:
            guard !value.isEmpty else { return nil }
            // 检测是否为数字
            if let _ = Double(value) {
                return "\(field) \(op.rawValue) \(value)"
            } else {
                return "\(field) \(op.rawValue) '\(value.replacingOccurrences(of: "'", with: "''"))'"
            }
        }
    }
}

struct TableDataView: View {
    let table: String
    let driver: any DatabaseDriver

    @State private var results: [[String: String]] = []
    @State private var isLoading: Bool = true
    @State private var errorMessage: String?
    @State private var executionTime: TimeInterval = 0
    @State private var isRefreshHovering: Bool = false
    
    // 分页状态
    @State private var currentPage: Int = 1
    @State private var pageSize: Int = 50  // 默认 50 条，平衡性能和用户体验
    @State private var totalCount: Int = 0
    @State private var pageInputText: String = "1"
    
    // 排序状态
    @State private var sortColumn: String? = nil
    @State private var sortOrder: SortOrder = .ascending
    
    // 筛选状态
    @State private var filters: [FilterCondition] = []
    @State private var availableColumns: [String] = []
    @State private var showFilterBar: Bool = false
    
    // 编辑状态
    @State private var isEditMode: Bool = false
    @State private var pendingEdits: [CellEdit] = []
    @State private var selectedRow: Int? = nil
    @State private var isSaving: Bool = false
    @State private var saveError: String? = nil
    @State private var showSQLPreview: Bool = false
    @State private var previewSQLStatements: [String] = []
    
    // 可选的每页数量（从小到大，方便性能调优）
    private let pageSizeOptions = [20, 50, 100, 200]
    
    // 计算总页数
    private var totalPages: Int {
        max(1, Int(ceil(Double(totalCount) / Double(pageSize))))
    }
    
    // 当前显示的记录范围
    private var displayRange: String {
        guard totalCount > 0 else { return "0 条" }
        let start = (currentPage - 1) * pageSize + 1
        let end = min(currentPage * pageSize, totalCount)
        return "\(start)-\(end) / \(totalCount) 条"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 工具栏
            tableToolbar
            
            // 筛选栏
            if showFilterBar {
                filterBar
            }
            
            // 内容区域
            if isLoading {
                loadingView
            } else if let error = errorMessage {
                errorView(error)
            } else if results.isEmpty {
                emptyView
            } else {
                EditableResultsGridView(
                    results: results,
                    tableName: table,
                    sortColumn: sortColumn,
                    sortOrder: sortOrder,
                    isEditable: isEditMode,
                    onSort: { column in
                        handleSort(column: column)
                    },
                    onCellEdit: { edit in
                        handleCellEdit(edit)
                    },
                    onRowSelect: { row in
                        selectedRow = row
                    },
                    onCopySQL: { sql in
                        print("[SQL 已复制] \(sql)")
                    }
                )
            }
            
            // 编辑确认栏
            if !pendingEdits.isEmpty {
                editConfirmBar
            }
            
            // 分页栏
            if !isLoading && errorMessage == nil && totalCount > 0 {
                paginationBar
            }
        }
        .background(AppColors.background)
        .id(table)
        .sheet(isPresented: $showSQLPreview) {
            SQLPreviewSheet(
                sqlStatements: previewSQLStatements,
                isSaving: isSaving,
                saveError: saveError,
                onConfirm: { Task { await executeChanges() } },
                onCancel: { showSQLPreview = false }
            )
        }
        .task(id: table) {
            // 切换表时重置状态
            currentPage = 1
            pageInputText = "1"
            sortColumn = nil
            sortOrder = .ascending
            filters = []
            isEditMode = false
            pendingEdits = []
            selectedRow = nil
            await loadColumns()
            await loadData()
        }
    }
    
    // MARK: - 工具栏
    private var tableToolbar: some View {
        HStack(spacing: AppSpacing.md) {
            // 筛选按钮（最左边）
            FilterToggleButton(isActive: showFilterBar, hasFilters: !filters.isEmpty) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showFilterBar.toggle()
                }
            }
            
            // 表名
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "tablecells.fill")
                    .font(.system(size: 12))
                    .foregroundColor(AppColors.accent)
                
                Text(table)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppColors.primaryText)
            }
            
            Spacer()
            
            // 状态信息
            if isLoading {
                HStack(spacing: AppSpacing.xs) {
                    ProgressView()
                        .controlSize(.small)
                    Text("加载中...")
                        .font(.system(size: 11))
                        .foregroundColor(AppColors.secondaryText)
                }
            } else if errorMessage != nil {
                HStack(spacing: AppSpacing.xs) {
                    Circle()
                        .fill(AppColors.error)
                        .frame(width: 6, height: 6)
                    Text("错误")
                        .font(.system(size: 11))
                        .foregroundColor(AppColors.error)
                }
            } else {
                HStack(spacing: AppSpacing.sm) {
                    Text("\(results.count) 行")
                        .font(.system(size: 11))
                        .foregroundColor(AppColors.secondaryText)
                    
                    if executionTime > 0 {
                        Text("·")
                            .foregroundColor(AppColors.tertiaryText)
                        Text(String(format: "%.2fs", executionTime))
                            .font(.system(size: 11))
                            .foregroundColor(AppColors.secondaryText)
                    }
                }
            }
            
            // 编辑模式按钮
            EditModeButton(isActive: isEditMode, hasEdits: !pendingEdits.isEmpty) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    if isEditMode && !pendingEdits.isEmpty {
                        // 如果有未保存的编辑，提示用户
                    }
                    isEditMode.toggle()
                    print("[TableDataView] 编辑模式切换: isEditMode=\(isEditMode)")
                    if !isEditMode {
                        pendingEdits = []
                    }
                }
            }
            
            // 提交更改按钮（有编辑时显示）
            if !pendingEdits.isEmpty {
                Button(action: showSQLPreviewSheet) {
                    HStack(spacing: AppSpacing.xs) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 11, weight: .medium))
                        Text("提交更改 (\(pendingEdits.count))")
                            .font(.system(size: 12, weight: .medium))
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(AppColors.warning)
            }
            
            // 刷新按钮
            Image(systemName: "arrow.clockwise")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(AppColors.secondaryText)
                .frame(width: 26, height: 26)
                .background(isRefreshHovering ? AppColors.hover : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.sm))
                .onHover { isRefreshHovering = $0 }
                .onTapGesture {
                    Task { await loadData() }
                }
                .help("刷新")
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.sm)
        .background(AppColors.secondaryBackground)
    }
    
    // MARK: - 筛选栏
    private var filterBar: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            // 列信息加载状态
            if availableColumns.isEmpty {
                HStack(spacing: AppSpacing.sm) {
                    ProgressView()
                        .controlSize(.small)
                    Text("正在加载列信息...")
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.secondaryText)
                }
                .padding(.vertical, AppSpacing.xs)
            }
            
            // 筛选条件列表
            ForEach($filters) { $filter in
                FilterRowView(
                    filter: $filter,
                    columns: availableColumns,
                    onDelete: {
                        filters.removeAll { $0.id == filter.id }
                        applyFilters()
                    }
                )
            }
            
            // 操作按钮
            HStack(spacing: AppSpacing.sm) {
                // 添加条件按钮
                Button(action: addFilter) {
                    HStack(spacing: AppSpacing.xs) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 12))
                        Text("添加条件")
                            .font(.system(size: 12))
                    }
                }
                .buttonStyle(.plain)
                .foregroundColor(availableColumns.isEmpty ? AppColors.tertiaryText : AppColors.accent)
                .disabled(availableColumns.isEmpty)
                
                // 列数提示
                if !availableColumns.isEmpty {
                    Text("可筛选 \(availableColumns.count) 个字段")
                        .font(.system(size: 11))
                        .foregroundColor(AppColors.tertiaryText)
                }
                
                Spacer()
                
                // 清除所有按钮
                if !filters.isEmpty {
                    Button(action: clearFilters) {
                        HStack(spacing: AppSpacing.xs) {
                            Image(systemName: "xmark.circle")
                                .font(.system(size: 12))
                            Text("清除全部")
                                .font(.system(size: 12))
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(AppColors.error)
                }
                
                // 应用按钮
                Button(action: applyFilters) {
                    HStack(spacing: AppSpacing.xs) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12))
                        Text("应用筛选")
                            .font(.system(size: 12))
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(filters.isEmpty)
            }
        }
        .padding(AppSpacing.md)
        .background(AppColors.tertiaryBackground)
        .overlay(
            Rectangle()
                .fill(AppColors.separator)
                .frame(height: 1),
            alignment: .bottom
        )
    }
    
    // MARK: - 加载视图
    private var loadingView: some View {
        AppLoadingState(message: "加载数据...")
    }
    
    // MARK: - 错误视图
    private func errorView(_ error: String) -> some View {
        AppErrorState(message: error) {
            Task { await loadData() }
        }
    }
    
    // MARK: - 空视图
    private var emptyView: some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: "tray")
                .font(.system(size: 14))
                .foregroundColor(AppColors.tertiaryText)
            
            Text("表为空")
                .font(.system(size: 12))
                .foregroundColor(AppColors.secondaryText)
        }
        .padding(AppSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - 分页栏
    private var paginationBar: some View {
        HStack(spacing: AppSpacing.md) {
            // 左侧：记录范围
            Text(displayRange)
                .font(.system(size: 11))
                .foregroundColor(AppColors.secondaryText)
            
            Spacer()
            
            // 中间：每页数量选择
            HStack(spacing: AppSpacing.xs) {
                Text("每页")
                    .font(.system(size: 11))
                    .foregroundColor(AppColors.secondaryText)
                
                Picker("", selection: $pageSize) {
                    ForEach(pageSizeOptions, id: \.self) { size in
                        Text("\(size)").tag(size)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 70)
                .onChange(of: pageSize) { _, _ in
                    currentPage = 1
                    pageInputText = "1"
                    Task { await loadData() }
                }
                
                Text("条")
                    .font(.system(size: 11))
                    .foregroundColor(AppColors.secondaryText)
            }
            
            // 右侧：分页控制
            HStack(spacing: AppSpacing.sm) {
                // 首页按钮
                PaginationButton(icon: "chevron.left.2", enabled: currentPage > 1) {
                    goToPage(1)
                }
                
                // 上一页按钮
                PaginationButton(icon: "chevron.left", enabled: currentPage > 1) {
                    goToPage(currentPage - 1)
                }
                
                // 页码输入
                HStack(spacing: AppSpacing.xs) {
                    TextField("", text: $pageInputText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 11))
                        .frame(width: 40)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, AppSpacing.xs)
                        .padding(.vertical, AppSpacing.xxs)
                        .background(AppColors.tertiaryBackground)
                        .cornerRadius(AppRadius.sm)
                        .onSubmit {
                            if let page = Int(pageInputText), page >= 1 && page <= totalPages {
                                goToPage(page)
                            } else {
                                pageInputText = "\(currentPage)"
                            }
                        }
                    
                    Text("/ \(totalPages)")
                        .font(.system(size: 11))
                        .foregroundColor(AppColors.secondaryText)
                }
                
                // 下一页按钮
                PaginationButton(icon: "chevron.right", enabled: currentPage < totalPages) {
                    goToPage(currentPage + 1)
                }
                
                // 末页按钮
                PaginationButton(icon: "chevron.right.2", enabled: currentPage < totalPages) {
                    goToPage(totalPages)
                }
            }
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.sm)
        .background(AppColors.secondaryBackground)
        .overlay(
            Rectangle()
                .fill(AppColors.separator)
                .frame(height: 1),
            alignment: .top
        )
    }
    
    // MARK: - 编辑确认栏
    private var editConfirmBar: some View {
        HStack(spacing: AppSpacing.md) {
            // 编辑状态信息
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "pencil.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(AppColors.warning)
                
                Text("\(pendingEdits.count) 个修改待提交")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AppColors.primaryText)
            }
            
            // 修改详情
            Text("·")
                .foregroundColor(AppColors.tertiaryText)
            
            // 显示修改的列
            let editedColumns = Set(pendingEdits.map { $0.column })
            Text("涉及列: \(editedColumns.joined(separator: ", "))")
                .font(.system(size: 11))
                .foregroundColor(AppColors.secondaryText)
                .lineLimit(1)
            
            Spacer()
            
            // 放弃修改按钮
            Button(action: cancelEdits) {
                HStack(spacing: AppSpacing.xs) {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 11, weight: .medium))
                    Text("放弃修改")
                        .font(.system(size: 12))
                }
            }
            .buttonStyle(.plain)
            .foregroundColor(AppColors.secondaryText)
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.sm)
            .background(AppColors.hover)
            .cornerRadius(AppRadius.sm)
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.sm)
        .background(AppColors.warning.opacity(0.1))
        .overlay(
            Rectangle()
                .fill(AppColors.warning)
                .frame(height: 2),
            alignment: .top
        )
    }
    
    // MARK: - 编辑操作
    private func handleCellEdit(_ edit: CellEdit) {
        print("[TableDataView] handleCellEdit 被调用: row=\(edit.row), col=\(edit.column), old='\(edit.oldValue ?? "nil")', new='\(edit.newValue ?? "nil")'")
        
        // 检查是否已有此单元格的编辑
        if let index = pendingEdits.firstIndex(where: { $0.row == edit.row && $0.column == edit.column }) {
            // 如果新值等于原始值，移除编辑记录
            if edit.newValue == edit.oldValue {
                print("[TableDataView] 移除编辑记录（值恢复原状）")
                pendingEdits.remove(at: index)
            } else {
                print("[TableDataView] 更新编辑记录")
                pendingEdits[index] = edit
            }
        } else if edit.newValue != edit.oldValue {
            print("[TableDataView] 添加新编辑记录, 当前编辑数: \(pendingEdits.count + 1)")
            pendingEdits.append(edit)
        }
        saveError = nil
    }
    
    private func cancelEdits() {
        pendingEdits = []
        saveError = nil
        // 重新加载数据以恢复原始值
        Task { await loadData() }
    }
    
    // 显示 SQL 预览弹框
    private func showSQLPreviewSheet() {
        previewSQLStatements = generateUpdateSQL()
        saveError = nil
        showSQLPreview = true
    }
    
    // 生成所有 UPDATE SQL 语句
    private func generateUpdateSQL() -> [String] {
        var sqlStatements: [String] = []
        
        // 按行分组编辑
        var editsByRow: [Int: [CellEdit]] = [:]
        for edit in pendingEdits {
            editsByRow[edit.row, default: []].append(edit)
        }
        
        // 获取原始数据（过滤掉 __columns__ 元数据行）
        let originalResults = results.filter { $0["__columns__"] == nil }
        
        // 获取列信息：优先使用 availableColumns，其次从 __columns__ 元数据获取
        var columns: [String] = availableColumns
        if columns.isEmpty, let columnsStr = results.first?["__columns__"] {
            columns = columnsStr.split(separator: ",").map(String.init)
        }
        
        // 如果 columns 仍为空，使用 originalRow 的所有键（排除元数据键）
        if columns.isEmpty, let firstRow = originalResults.first {
            columns = Array(firstRow.keys).filter { !$0.hasPrefix("__") }
        }
        
        // 查找主键列（常见命名：id, ID, Id, 或 表名_id, 表名Id）
        let primaryKeyColumn = findPrimaryKeyColumn(in: columns)
        
        print("[generateUpdateSQL] pendingEdits=\(pendingEdits.count), originalResults=\(originalResults.count), columns=\(columns), primaryKey=\(primaryKeyColumn ?? "none")")
        
        for (row, edits) in editsByRow.sorted(by: { $0.key < $1.key }) {
            guard row < originalResults.count else {
                print("[generateUpdateSQL] 跳过行 \(row)：超出 originalResults 范围")
                continue
            }
            let originalRow = originalResults[row]
            
            // 构建 SET 子句（只包含用户编辑的字段）
            let setClauses = edits.map { edit -> String in
                if let newValue = edit.newValue {
                    // 检测是否为数字类型
                    if let _ = Double(newValue) {
                        return "\(edit.column) = \(newValue)"
                    } else {
                        return "\(edit.column) = '\(newValue.replacingOccurrences(of: "'", with: "''"))'"
                    }
                } else {
                    return "\(edit.column) = NULL"
                }
            }
            
            // 构建 WHERE 子句（优先使用主键）
            var whereClause: String
            if let pkColumn = primaryKeyColumn, let pkValue = originalRow[pkColumn] {
                // 使用主键定位行
                if let _ = Int(pkValue) {
                    whereClause = "\(pkColumn) = \(pkValue)"
                } else {
                    whereClause = "\(pkColumn) = '\(pkValue.replacingOccurrences(of: "'", with: "''"))'"
                }
            } else {
                // 没有主键，使用所有列值（回退方案）
                var whereClauses: [String] = []
                for col in columns {
                    if let value = originalRow[col] {
                        whereClauses.append("\(col) = '\(value.replacingOccurrences(of: "'", with: "''"))'")
                    } else {
                        whereClauses.append("\(col) IS NULL")
                    }
                }
                whereClause = whereClauses.isEmpty ? "1=0" : whereClauses.joined(separator: " AND ")
            }
            
            let sql = "UPDATE \(table) SET \(setClauses.joined(separator: ", ")) WHERE \(whereClause);"
            print("[generateUpdateSQL] 生成 SQL: \(sql)")
            sqlStatements.append(sql)
        }
        
        print("[generateUpdateSQL] 共生成 \(sqlStatements.count) 条 SQL")
        return sqlStatements
    }
    
    // 查找主键列
    private func findPrimaryKeyColumn(in columns: [String]) -> String? {
        // 常见主键命名模式（按优先级）
        let primaryKeyPatterns = [
            "id",                           // 最常见
            "ID",
            "Id",
            "\(table)_id",                  // 表名_id
            "\(table)Id",                   // 表名Id
            "\(table.lowercased())_id",
            "\(table.lowercased())id",
        ]
        
        for pattern in primaryKeyPatterns {
            if columns.contains(pattern) {
                return pattern
            }
        }
        
        // 如果没有找到，检查是否有以 _id 或 Id 结尾的列
        for col in columns {
            if col.lowercased() == "id" || col.hasSuffix("_id") || col.hasSuffix("Id") {
                return col
            }
        }
        
        return nil
    }
    
    // 执行 SQL 更改
    private func executeChanges() async {
        guard !previewSQLStatements.isEmpty else { return }
        
        isSaving = true
        saveError = nil
        
        do {
            for sql in previewSQLStatements {
                print("[执行 SQL] \(sql)")
                _ = try await driver.execute(sql: sql)
            }
            
            // 保存成功，清空编辑并刷新数据
            await MainActor.run {
                pendingEdits = []
                previewSQLStatements = []
                isSaving = false
                showSQLPreview = false
            }
            await loadData()
            
        } catch {
            await MainActor.run {
                saveError = error.localizedDescription
                isSaving = false
            }
        }
    }
    
    // MARK: - 分页操作
    private func goToPage(_ page: Int) {
        guard page >= 1 && page <= totalPages && page != currentPage else { return }
        currentPage = page
        pageInputText = "\(page)"
        Task { await loadData() }
    }
    
    // MARK: - 排序操作
    private func handleSort(column: String) {
        if sortColumn == column {
            // 同一列：切换排序方向
            sortOrder.toggle()
        } else {
            // 新列：默认升序
            sortColumn = column
            sortOrder = .ascending
        }
        // 排序后回到第一页
        currentPage = 1
        pageInputText = "1"
        Task { await loadData() }
    }
    
    // MARK: - 筛选操作
    private func addFilter() {
        let newFilter = FilterCondition(
            field: availableColumns.first ?? "",
            op: .equal,
            value: ""
        )
        filters.append(newFilter)
    }
    
    private func clearFilters() {
        filters.removeAll()
        applyFilters()
    }
    
    private func applyFilters() {
        currentPage = 1
        pageInputText = "1"
        Task { await loadData() }
    }
    
    // 构建 WHERE 子句
    private func buildWhereClause() -> String? {
        let conditions = filters.compactMap { $0.toSQL() }
        guard !conditions.isEmpty else { return nil }
        return conditions.joined(separator: " AND ")
    }
    
    // 加载列信息
    private func loadColumns() async {
        do {
            // 方案1：通过 PRAGMA table_info 获取列信息（更可靠）
            let pragmaSql = "PRAGMA table_info(\(table))"
            let pragmaResult = try await driver.execute(sql: pragmaSql)
            
            // 过滤掉 __columns__ 元数据行，提取 name 字段
            let cols = pragmaResult
                .filter { $0["__columns__"] == nil }
                .compactMap { $0["name"] }
            
            if !cols.isEmpty {
                await MainActor.run {
                    self.availableColumns = cols
                }
                return
            }
            
            // 方案2：通过 LIMIT 1 查询获取列名（备用）
            let sql = "SELECT * FROM \(table) LIMIT 1"
            let result = try await driver.execute(sql: sql)
            
            if let first = result.first, let columnsStr = first["__columns__"] {
                let columns = columnsStr.split(separator: ",").map { String($0) }
                await MainActor.run {
                    self.availableColumns = columns
                }
            }
        } catch {
            // 忽略错误，使用空列表
            print("[loadColumns] 加载列信息失败: \(error)")
        }
    }
    
    // 从当前结果中提取列信息（作为最后备用）
    private func extractColumnsFromResults() {
        if let first = results.first, let columnsStr = first["__columns__"] {
            let cols = columnsStr.split(separator: ",").map { String($0) }
            if availableColumns.isEmpty && !cols.isEmpty {
                availableColumns = cols
            }
        }
    }

    private func loadData() async {
        isLoading = true
        errorMessage = nil
        let startTime = Date()

        do {
            // 构建 WHERE 子句
            let whereClause = buildWhereClause()
            let whereSQL = whereClause.map { " WHERE \($0)" } ?? ""
            
            // 首先获取总记录数（带筛选条件）
            let countSql = "SELECT COUNT(*) as count FROM \(table)\(whereSQL)"
            let countResult = try await driver.execute(sql: countSql)
            
            // 跳过 __columns__ 元数据行
            let countData = countResult.filter { $0["__columns__"] == nil }
            if let countRow = countData.first, let countStr = countRow["count"], let count = Int(countStr) {
                await MainActor.run {
                    self.totalCount = count
                }
            }
            
            // 计算偏移量
            let offset = (currentPage - 1) * pageSize
            
            // 构建 SQL（带筛选、排序、分页）
            var sql = "SELECT * FROM \(table)\(whereSQL)"
            if let sortCol = sortColumn {
                sql += " ORDER BY \(sortCol) \(sortOrder.sqlKeyword)"
            }
            sql += " LIMIT \(pageSize) OFFSET \(offset)"
            
            let data = try await driver.execute(sql: sql)
            let elapsed = Date().timeIntervalSince(startTime)

            await MainActor.run {
                self.results = data
                self.executionTime = elapsed
                self.isLoading = false
                // 如果列信息为空，从结果中提取
                self.extractColumnsFromResults()
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
}

// MARK: - 分页按钮组件
struct PaginationButton: View {
    let icon: String
    let enabled: Bool
    let action: () -> Void
    
    @State private var isHovering: Bool = false
    
    var body: some View {
        Image(systemName: icon)
            .font(.system(size: 10, weight: .medium))
            .foregroundColor(enabled ? AppColors.primaryText : AppColors.tertiaryText)
            .frame(width: 24, height: 24)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.sm)
                    .fill(isHovering && enabled ? AppColors.hover : Color.clear)
            )
            .onHover { isHovering = $0 }
            .onTapGesture {
                if enabled { action() }
            }
            .allowsHitTesting(enabled)
    }
}

// MARK: - 筛选切换按钮
struct FilterToggleButton: View {
    let isActive: Bool
    let hasFilters: Bool
    let action: () -> Void
    
    @State private var isHovering: Bool = false
    
    var body: some View {
        HStack(spacing: AppSpacing.xs) {
            Image(systemName: "line.3.horizontal.decrease.circle\(hasFilters ? ".fill" : "")")
                .font(.system(size: 12, weight: .medium))
            
            if hasFilters {
                Text("筛选中")
                    .font(.system(size: 11))
            }
        }
        .foregroundColor(hasFilters ? AppColors.accent : AppColors.secondaryText)
        .padding(.horizontal, AppSpacing.sm)
        .padding(.vertical, AppSpacing.xs)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.sm)
                .fill(isActive ? AppColors.accentSubtle : (isHovering ? AppColors.hover : Color.clear))
        )
        .onHover { isHovering = $0 }
        .onTapGesture { action() }
        .help("筛选")
    }
}

// MARK: - 编辑模式按钮
struct EditModeButton: View {
    let isActive: Bool
    let hasEdits: Bool
    let action: () -> Void
    
    @State private var isHovering: Bool = false
    
    var body: some View {
        HStack(spacing: AppSpacing.xs) {
            Image(systemName: isActive ? "pencil.circle.fill" : "pencil.circle")
                .font(.system(size: 12, weight: .medium))
            
            if isActive {
                Text(hasEdits ? "编辑中*" : "编辑中")
                    .font(.system(size: 11))
            }
        }
        .foregroundColor(isActive ? (hasEdits ? AppColors.warning : AppColors.accent) : AppColors.secondaryText)
        .padding(.horizontal, AppSpacing.sm)
        .padding(.vertical, AppSpacing.xs)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.sm)
                .fill(isActive ? (hasEdits ? AppColors.warning.opacity(0.15) : AppColors.accentSubtle) : (isHovering ? AppColors.hover : Color.clear))
        )
        .onHover { isHovering = $0 }
        .onTapGesture { action() }
        .help(isActive ? "退出编辑模式" : "进入编辑模式")
    }
}

// MARK: - 筛选行视图
struct FilterRowView: View {
    @Binding var filter: FilterCondition
    let columns: [String]
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            // 字段选择
            if columns.isEmpty {
                // 列信息为空时显示提示
                Text("加载列信息中...")
                    .font(.system(size: 12))
                    .foregroundColor(AppColors.tertiaryText)
                    .padding(.horizontal, AppSpacing.sm)
                    .padding(.vertical, AppSpacing.xs)
                    .background(AppColors.tertiaryBackground)
                    .cornerRadius(AppRadius.sm)
                    .frame(width: 120)
            } else {
                Picker("", selection: $filter.field) {
                    ForEach(columns, id: \.self) { column in
                        Text(column).tag(column)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 120)
                .onChange(of: columns) { oldValue, newValue in
                    // 当列信息更新时，如果当前选中的字段不在列表中，自动选择第一个
                    if !newValue.isEmpty && !newValue.contains(filter.field) {
                        filter.field = newValue.first ?? ""
                    }
                }
            }
            
            // 操作符选择
            Picker("", selection: $filter.op) {
                ForEach(FilterOperator.allCases, id: \.self) { op in
                    Text(op.displayName).tag(op)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 140)
            
            // 值输入（如果需要）
            if filter.op.needsValue {
                TextField("输入值...", text: $filter.value)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .padding(.horizontal, AppSpacing.sm)
                    .padding(.vertical, AppSpacing.xs)
                    .background(AppColors.secondaryBackground)
                    .cornerRadius(AppRadius.sm)
                    .frame(minWidth: 100)
            } else {
                Spacer()
            }
            
            // 删除按钮
            Button(action: onDelete) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(AppColors.tertiaryText)
            }
            .buttonStyle(.plain)
            .help("删除此条件")
        }
    }
}

#Preview {
    TableDataView(
        table: "users",
        driver: MockDriver()
    )
}

// MARK: - SQL 预览弹框
struct SQLPreviewSheet: View {
    let sqlStatements: [String]
    let isSaving: Bool
    let saveError: String?
    let onConfirm: () -> Void
    let onCancel: () -> Void
    
    @State private var copiedIndex: Int? = nil
    
    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            HStack {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 16))
                    .foregroundColor(AppColors.accent)
                
                Text("确认 SQL 更改")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppColors.primaryText)
                
                Spacer()
                
                Text("\(sqlStatements.count) 条语句")
                    .font(.system(size: 12))
                    .foregroundColor(AppColors.secondaryText)
                    .padding(.horizontal, AppSpacing.sm)
                    .padding(.vertical, AppSpacing.xxs)
                    .background(AppColors.tertiaryBackground)
                    .cornerRadius(AppRadius.sm)
            }
            .padding(AppSpacing.md)
            .background(AppColors.secondaryBackground)
            
            Divider()
            
            // SQL 语句列表
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    ForEach(Array(sqlStatements.enumerated()), id: \.offset) { index, sql in
                        SQLStatementRow(
                            index: index + 1,
                            sql: sql,
                            isCopied: copiedIndex == index,
                            onCopy: {
                                copyToClipboard(sql)
                                copiedIndex = index
                                // 2秒后重置复制状态
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                    if copiedIndex == index {
                                        copiedIndex = nil
                                    }
                                }
                            }
                        )
                    }
                }
                .padding(AppSpacing.md)
            }
            .frame(minHeight: 200, maxHeight: 400)
            .background(AppColors.background)
            
            Divider()
            
            // 错误信息
            if let error = saveError {
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(AppColors.error)
                    
                    Text(error)
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.error)
                        .lineLimit(2)
                    
                    Spacer()
                }
                .padding(AppSpacing.md)
                .background(AppColors.error.opacity(0.1))
            }
            
            // 底部操作栏
            HStack(spacing: AppSpacing.md) {
                // 警告提示
                HStack(spacing: AppSpacing.xs) {
                    Image(systemName: "exclamationmark.circle")
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.warning)
                    Text("执行后将直接修改数据库")
                        .font(.system(size: 11))
                        .foregroundColor(AppColors.secondaryText)
                }
                
                Spacer()
                
                // 取消按钮
                Button(action: onCancel) {
                    Text("取消")
                        .font(.system(size: 13))
                }
                .buttonStyle(.plain)
                .foregroundColor(AppColors.secondaryText)
                .padding(.horizontal, AppSpacing.lg)
                .padding(.vertical, AppSpacing.sm)
                .background(AppColors.hover)
                .cornerRadius(AppRadius.md)
                .disabled(isSaving)
                
                // 确认按钮
                Button(action: onConfirm) {
                    HStack(spacing: AppSpacing.xs) {
                        if isSaving {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 12))
                        }
                        Text(isSaving ? "执行中..." : "确认执行")
                            .font(.system(size: 13, weight: .medium))
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isSaving)
            }
            .padding(AppSpacing.md)
            .background(AppColors.secondaryBackground)
        }
        .frame(width: 600)
        .background(AppColors.background)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
    }
    
    private func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}

// MARK: - SQL 语句行
struct SQLStatementRow: View {
    let index: Int
    let sql: String
    let isCopied: Bool
    let onCopy: () -> Void
    
    @State private var isHovering: Bool = false
    
    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.sm) {
            // 序号
            Text("\(index)")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(AppColors.tertiaryText)
                .frame(width: 24, alignment: .trailing)
            
            // SQL 语句
            Text(sql)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(AppColors.primaryText)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // 复制按钮
            Button(action: onCopy) {
                Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 11))
                    .foregroundColor(isCopied ? AppColors.success : AppColors.secondaryText)
            }
            .buttonStyle(.plain)
            .opacity(isHovering || isCopied ? 1 : 0.5)
            .help(isCopied ? "已复制" : "复制 SQL")
        }
        .padding(AppSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.sm)
                .fill(isHovering ? AppColors.hover : AppColors.tertiaryBackground)
        )
        .onHover { isHovering = $0 }
    }
}

// Mock driver for preview
struct MockDriver: DatabaseDriver {
    func connect() async throws {}
    func disconnect() async {}
    func fetchDatabases() async throws -> [String] { [] }
    func fetchTables() async throws -> [String] { [] }
    func fetchTablesWithInfo() async throws -> [TableInfo] { [] }
    func fetchColumnsWithInfo(for table: String) async throws -> [ColumnInfo] { [] }
    func execute(sql: String) async throws -> [[String: String]] {
        // 模拟 COUNT 查询
        if sql.lowercased().contains("count") {
            return [["count": "150"]]
        }
        // 模拟数据查询
        return [
            ["__columns__": "id,name,email"],
            ["id": "1", "name": "Alice", "email": "alice@example.com"],
            ["id": "2", "name": "Bob", "email": "bob@example.com"]
        ]
    }
    func getDDL(for table: String) async throws -> String { "" }
}
