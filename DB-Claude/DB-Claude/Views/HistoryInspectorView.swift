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
    
    /// 从 SQL 语句判断类型
    static func detect(from sql: String) -> SQLStatementType {
        let trimmed = sql.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        
        if trimmed.hasPrefix("SELECT") { return .select }
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
    
    var body: some View {
        VStack(spacing: 0) {
            // 标题栏 - 使用 AppToolbar
            AppToolbar(title: "历史记录") {
                EmptyView()
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
                    LazyVStack(spacing: AppSpacing.xs) {
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
                    .padding(AppSpacing.sm)
                }
            }
        }
        .background(AppColors.background)
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
                        HStack {
                            Image(systemName: type.icon)
                            Text(type.rawValue)
                            Spacer()
                            if countForType(type) > 0 {
                                Text("\(countForType(type))")
                                    .foregroundColor(.secondary)
                            }
                            if selectedType == type {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                FilterChip(
                    title: secondaryTypes.contains(selectedType) ? selectedType.rawValue : "更多",
                    icon: secondaryTypes.contains(selectedType) ? selectedType.icon : "ellipsis",
                    isSelected: secondaryTypes.contains(selectedType),
                    count: nil
                ) {}
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            
            Spacer()
        }
    }
}

// MARK: - 筛选芯片组件
private struct FilterChip: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let count: Int?
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                Text(title)
                    .font(AppTypography.small)
                if let count = count, count > 0 {
                    Text("\(count)")
                        .font(.system(size: 9, weight: .medium))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(
                            Capsule()
                                .fill(isSelected ? Color.white.opacity(0.3) : AppColors.tertiaryBackground)
                        )
                }
            }
            .padding(.horizontal, AppSpacing.sm)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.sm)
                    .fill(isSelected ? AppColors.accent : AppColors.secondaryBackground)
            )
            .foregroundColor(isSelected ? .white : AppColors.primaryText)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 历史记录项行
private struct HistoryItemRow: View {
    let item: QueryHistory
    let onTap: () -> Void
    let onCopy: () -> Void
    let onDelete: () -> Void

    @State private var isHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            // SQL 内容（带语法高亮）
            HighlightedSQLText(sql: item.sql)
                .lineLimit(3)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)

            // 元信息
            HStack(spacing: AppSpacing.md) {
                // 时间
                HStack(spacing: AppSpacing.xs) {
                    Image(systemName: "clock")
                        .font(.system(size: 10))
                    Text(item.timestamp, style: .time)
                }

                // 状态
                HStack(spacing: AppSpacing.xs) {
                    Circle()
                        .fill(item.status == "Error" ? AppColors.error : AppColors.success)
                        .frame(width: 7, height: 7)
                    Text(String(format: "%.3fs", item.executionTime))
                }

                Spacer()
            }
            .font(AppTypography.small)
            .foregroundColor(AppColors.secondaryText)
        }
        .padding(AppSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.md)
                .fill(isHovering ? AppColors.hover : AppColors.secondaryBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.md)
                .stroke(AppColors.border.opacity(0.5), lineWidth: 0.5)
        )
        .scaleEffect(isHovering ? 1.01 : 1.0)
        .animation(AppAnimation.fast, value: isHovering)
        .contentShape(Rectangle())
        .draggable(item.sql) // 支持拖拽 SQL 到编辑器
        .onHover { isHovering = $0 }
        .onTapGesture { onTap() }
        .contextMenu {
            Button {
                onCopy()
            } label: {
                Label("复制 SQL", systemImage: "doc.on.doc")
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
