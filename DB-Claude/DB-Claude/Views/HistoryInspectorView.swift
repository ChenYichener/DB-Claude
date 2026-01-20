import SwiftUI
import SwiftData

struct HistoryInspectorView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \QueryHistory.timestamp, order: .reverse) private var historyItems: [QueryHistory]
    
    var onSelectSQL: (String) -> Void
    var connectionID: UUID?
    
    var filteredHistory: [QueryHistory] {
        if let cid = connectionID {
            return historyItems.filter { $0.connectionID == cid }
        }
        return historyItems
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            HStack {
                Text("历史记录")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppColors.primaryText)
                
                Spacer()
                
                Text("\(filteredHistory.count)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(AppColors.secondaryText)
                    .padding(.horizontal, AppSpacing.sm)
                    .padding(.vertical, AppSpacing.xxs)
                    .background(AppColors.tertiaryBackground)
                    .clipShape(Capsule())
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.sm)
            .background(AppColors.secondaryBackground)
            
            // 列表
            if filteredHistory.isEmpty {
                emptyState
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
    
    private var emptyState: some View {
        VStack(spacing: AppSpacing.md) {
            Image(systemName: "clock")
                .font(.system(size: 28, weight: .light))
                .foregroundColor(AppColors.tertiaryText)
            
            Text("暂无历史记录")
                .font(.system(size: 13))
                .foregroundColor(AppColors.secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - 历史记录项行 - 扁平化设计
private struct HistoryItemRow: View {
    let item: QueryHistory
    let onTap: () -> Void
    let onCopy: () -> Void
    let onDelete: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            // SQL 内容
            Text(item.sql)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(AppColors.primaryText)
                .lineLimit(3)
            
            // 元信息
            HStack(spacing: AppSpacing.md) {
                // 时间
                HStack(spacing: AppSpacing.xxs) {
                    Image(systemName: "clock")
                        .font(.system(size: 9))
                    Text(item.timestamp, style: .time)
                }
                
                // 状态
                HStack(spacing: AppSpacing.xxs) {
                    Circle()
                        .fill(item.status == "Error" ? AppColors.error : AppColors.success)
                        .frame(width: 6, height: 6)
                    Text(String(format: "%.3fs", item.executionTime))
                }
                
                Spacer()
            }
            .font(.system(size: 10))
            .foregroundColor(AppColors.secondaryText)
        }
        .padding(AppSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.md)
                .fill(isHovering ? AppColors.hover : AppColors.secondaryBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.md)
                .stroke(AppColors.border, lineWidth: 1)
        )
        .contentShape(Rectangle())
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
