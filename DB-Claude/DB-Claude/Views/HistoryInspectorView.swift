import SwiftUI
import SwiftData

// MARK: - SQL 语句类型枚举
enum SQLStatementType: String, CaseIterable, Identifiable {
    case all = "全部"
    case select = "SELECT"
    case insert = "INSERT"
    case update = "UPDATE"
    case delete = "DELETE"
    case alter = "ALTER"
    case create = "CREATE"
    case drop = "DROP"
    case other = "其他"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .all: return "list.bullet"
        case .select: return "magnifyingglass"
        case .insert: return "plus.circle"
        case .update: return "pencil.circle"
        case .delete: return "minus.circle"
        case .alter: return "wrench"
        case .create: return "plus.square"
        case .drop: return "trash"
        case .other: return "ellipsis.circle"
        }
    }
    
    var color: Color {
        switch self {
        case .all: return AppColors.secondaryText
        case .select: return AppColors.accent
        case .insert: return AppColors.success
        case .update: return AppColors.warning
        case .delete: return AppColors.error
        case .alter: return .purple
        case .create: return .teal
        case .drop: return .red
        case .other: return AppColors.secondaryText
        }
    }
    
    /// 从 SQL 语句判断类型
    static func detect(from sql: String) -> SQLStatementType {
        let trimmed = sql.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        
        if trimmed.hasPrefix("SELECT") || trimmed.hasPrefix("EXPLAIN") { return .select }
        if trimmed.hasPrefix("INSERT") { return .insert }
        if trimmed.hasPrefix("UPDATE") { return .update }
        if trimmed.hasPrefix("DELETE") { return .delete }
        if trimmed.hasPrefix("ALTER") { return .alter }
        if trimmed.hasPrefix("CREATE") { return .create }
        if trimmed.hasPrefix("DROP") { return .drop }
        
        return .other
    }
}

struct HistoryInspectorView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \QueryHistory.timestamp, order: .reverse) private var historyItems: [QueryHistory]
    
    var onSelectSQL: (String) -> Void
    var connectionID: UUID?
    
    @State private var selectedType: SQLStatementType = .all
    @State private var showClearConfirmation: Bool = false
    
    var filteredHistory: [QueryHistory] {
        var items = historyItems
        
        // 按连接 ID 过滤
        if let cid = connectionID {
            items = items.filter { $0.connectionID == cid }
        }
        
        // 按 SQL 类型过滤
        if selectedType != .all {
            items = items.filter { SQLStatementType.detect(from: $0.sql) == selectedType }
        }
        
        return items
    }
    
    /// 当前连接的所有历史记录（用于清空）
    private var connectionHistory: [QueryHistory] {
        if let cid = connectionID {
            return historyItems.filter { $0.connectionID == cid }
        }
        return historyItems
    }
    
    /// 计算各类型数量（用于显示徽章）
    private func countForType(_ type: SQLStatementType) -> Int {
        var items = historyItems
        if let cid = connectionID {
            items = items.filter { $0.connectionID == cid }
        }
        
        if type == .all {
            return items.count
        }
        return items.filter { SQLStatementType.detect(from: $0.sql) == type }.count
    }
    
    /// 清空历史记录
    private func clearHistory() {
        withAnimation {
            for item in connectionHistory {
                modelContext.delete(item)
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 标题栏 - 使用 AppToolbar
            AppToolbar(title: "历史记录") {
                // 清空按钮
                if !connectionHistory.isEmpty {
                    Button {
                        showClearConfirmation = true
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 11))
                            .foregroundColor(AppColors.secondaryText)
                    }
                    .buttonStyle(.plain)
                    .help("清空历史记录")
                }
            } trailing: {
                AppBadge(count: filteredHistory.count)
            }
            
            // 筛选器
            SQLTypeFilterView(selectedType: $selectedType, countForType: countForType)
                .padding(.horizontal, AppSpacing.sm)
                .padding(.vertical, AppSpacing.xs)
            
            Divider()
            
            // 列表
            if filteredHistory.isEmpty {
                AppEmptyState(
                    icon: "clock",
                    title: selectedType == .all ? "暂无历史记录" : "暂无 \(selectedType.rawValue) 记录"
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(filteredHistory) { item in
                            HistoryItemRow(
                                item: item,
                                onTap: { onSelectSQL(item.sql) },
                                onCopy: {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(item.sql, forType: .string)
                                },
                                onDelete: {
                                    withAnimation {
                                        modelContext.delete(item)
                                    }
                                }
                            )
                        }
                    }
                    .padding(.horizontal, AppSpacing.xs)
                    .padding(.vertical, AppSpacing.xs)
                }
            }
        }
        .background(AppColors.background)
        .alert("清空历史记录", isPresented: $showClearConfirmation) {
            Button("取消", role: .cancel) { }
            Button("清空", role: .destructive) {
                clearHistory()
            }
        } message: {
            Text("确定要清空当前连接的所有历史记录吗？此操作无法撤销。")
        }
    }
}

// MARK: - SQL 类型筛选器视图
private struct SQLTypeFilterView: View {
    @Binding var selectedType: SQLStatementType
    let countForType: (SQLStatementType) -> Int
    
    // 常用类型（显示在第一行）
    private let primaryTypes: [SQLStatementType] = [.all, .select, .update, .insert]
    // 其他类型（显示在菜单中）
    private let secondaryTypes: [SQLStatementType] = [.delete, .alter, .create, .drop, .other]
    
    var body: some View {
        HStack(spacing: AppSpacing.xs) {
            // 主要筛选按钮
            ForEach(primaryTypes) { type in
                FilterChip(
                    title: type.rawValue,
                    icon: type.icon,
                    isSelected: selectedType == type,
                    count: type == .all ? nil : countForType(type)
                ) {
                    withAnimation(AppAnimation.fast) {
                        selectedType = type
                    }
                }
            }
            
            // 更多类型菜单
            Menu {
                ForEach(secondaryTypes) { type in
                    Button {
                        withAnimation(AppAnimation.fast) {
                            selectedType = type
                        }
                    } label: {
                        Label {
                            HStack {
                                Text(type.rawValue)
                                Spacer()
                                if countForType(type) > 0 {
                                    Text("\(countForType(type))")
                                        .foregroundColor(.secondary)
                                }
                            }
                        } icon: {
                            Image(systemName: selectedType == type ? "checkmark" : type.icon)
                        }
                    }
                }
            } label: {
                Image(systemName: secondaryTypes.contains(selectedType) ? selectedType.icon : "ellipsis")
                    .font(.system(size: 11))
                    .frame(minWidth: 28, minHeight: 24)
                    .padding(.horizontal, AppSpacing.xs)
                    .background(
                        RoundedRectangle(cornerRadius: AppRadius.sm)
                            .fill(secondaryTypes.contains(selectedType) ? AppColors.accent : AppColors.secondaryBackground)
                    )
                    .foregroundColor(secondaryTypes.contains(selectedType) ? .white : AppColors.primaryText)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help("更多")
            
            Spacer()
        }
    }
}

// MARK: - 筛选芯片组件（仅图标）
private struct FilterChip: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let count: Int?
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                if let count = count, count > 0 {
                    Text("\(count)")
                        .font(.system(size: 9, weight: .medium))
                }
            }
            .frame(minWidth: 28, minHeight: 24)
            .padding(.horizontal, AppSpacing.xs)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.sm)
                    .fill(isSelected ? AppColors.accent : AppColors.secondaryBackground)
            )
            .foregroundColor(isSelected ? .white : AppColors.primaryText)
        }
        .buttonStyle(.plain)
        .help(title)
    }
}

// MARK: - 历史记录项行
private struct HistoryItemRow: View {
    let item: QueryHistory
    let onTap: () -> Void
    let onCopy: () -> Void
    let onDelete: () -> Void

    @State private var isHovering = false
    @State private var isExpanded = false
    
    /// SQL 截断显示的最大字符数
    private let maxDisplayLength = 120
    
    /// 是否需要截断
    private var needsTruncation: Bool {
        item.sql.count > maxDisplayLength
    }
    
    /// 显示的 SQL 文本
    private var displaySQL: String {
        if needsTruncation && !isExpanded {
            // 截取并清理换行符
            let truncated = String(item.sql.prefix(maxDisplayLength))
                .replacingOccurrences(of: "\n", with: " ")
                .replacingOccurrences(of: "\r", with: "")
            return truncated.trimmingCharacters(in: .whitespaces) + "..."
        }
        return item.sql
    }
    
    /// SQL 类型
    private var sqlType: SQLStatementType {
        SQLStatementType.detect(from: item.sql)
    }

    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.sm) {
            // 左侧：类型指示器 + 状态
            VStack(spacing: 2) {
                // SQL 类型图标
                Image(systemName: sqlType.icon)
                    .font(.system(size: 9))
                    .foregroundColor(sqlType.color)
                
                // 状态指示点
                Circle()
                    .fill(item.status == "Error" ? AppColors.error : AppColors.success)
                    .frame(width: 5, height: 5)
            }
            .frame(width: 16)
            .padding(.top, 2)
            
            // 右侧：SQL 内容 + 元信息
            VStack(alignment: .leading, spacing: 3) {
                // SQL 内容（带语法高亮，小字体）
                HighlightedSQLText(sql: displaySQL, fontSize: 11)
                    .lineLimit(isExpanded ? nil : 2)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                // 元信息行
                HStack(spacing: AppSpacing.sm) {
                    // 时间
                    Text(item.timestamp, style: .time)
                        .font(.system(size: 9))
                        .foregroundColor(AppColors.tertiaryText)
                    
                    // 执行时间
                    Text(String(format: "%.2fs", item.executionTime))
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(AppColors.tertiaryText)
                    
                    // SQL 长度（大 SQL 显示）
                    if item.sql.count > 100 {
                        Text("\(item.sql.count) 字符")
                            .font(.system(size: 9))
                            .foregroundColor(AppColors.tertiaryText)
                    }
                    
                    Spacer()
                    
                    // 展开/收起按钮（仅大 SQL 显示）
                    if needsTruncation {
                        Button {
                            withAnimation(AppAnimation.fast) {
                                isExpanded.toggle()
                            }
                        } label: {
                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                .font(.system(size: 8, weight: .semibold))
                                .foregroundColor(AppColors.tertiaryText)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(.horizontal, AppSpacing.sm)
        .padding(.vertical, AppSpacing.xs)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.sm)
                .fill(isHovering ? AppColors.hover : Color.clear)
        )
        .contentShape(Rectangle())
        .draggable(item.sql) // 支持拖拽 SQL 到编辑器
        .onHover { isHovering = $0 }
        .onTapGesture { onTap() }
        .contextMenu {
            Button {
                onTap()
            } label: {
                Label("填充到编辑器", systemImage: "square.and.pencil")
            }
            
            Button {
                onCopy()
            } label: {
                Label("复制 SQL", systemImage: "doc.on.doc")
            }
            
            if needsTruncation {
                Button {
                    withAnimation(AppAnimation.fast) {
                        isExpanded.toggle()
                    }
                } label: {
                    Label(isExpanded ? "收起" : "展开全部", systemImage: isExpanded ? "chevron.up" : "chevron.down")
                }
            }

            Divider()

            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("删除", systemImage: "trash")
            }
        }
    }
}
