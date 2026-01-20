import SwiftUI
import UniformTypeIdentifiers

/// SQL 执行日志查看视图
struct SQLLogView: View {
    @ObservedObject private var logger = SQLLogger.shared
    @State private var searchText: String = ""
    @State private var selectedConnectionId: UUID? = nil
    @State private var showSuccessOnly: Bool = false
    @State private var showErrorsOnly: Bool = false
    
    private var filteredLogs: [SQLLogEntry] {
        var result = logger.logs
        
        // 按连接筛选
        if let connectionId = selectedConnectionId {
            result = result.filter { $0.connectionId == connectionId }
        }
        
        // 按状态筛选
        if showSuccessOnly {
            result = result.filter { $0.success }
        } else if showErrorsOnly {
            result = result.filter { !$0.success }
        }
        
        // 按搜索词筛选
        if !searchText.isEmpty {
            let lowercased = searchText.lowercased()
            result = result.filter {
                $0.sql.lowercased().contains(lowercased) ||
                $0.connectionName.lowercased().contains(lowercased)
            }
        }
        
        return result
    }
    
    // 获取唯一的连接列表
    private var uniqueConnections: [(id: UUID?, name: String)] {
        var seen = Set<String>()
        var connections: [(id: UUID?, name: String)] = [(nil, "全部连接")]
        
        for log in logger.logs {
            let key = log.connectionId?.uuidString ?? log.connectionName
            if !seen.contains(key) {
                seen.insert(key)
                connections.append((log.connectionId, log.connectionName))
            }
        }
        
        return connections
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 工具栏
            toolbarView
            
            AppDivider()
            
            // 日志列表
            if filteredLogs.isEmpty {
                AppEmptyState(
                    icon: "doc.text.magnifyingglass",
                    title: "暂无 SQL 执行记录",
                    message: "执行查询后，SQL 日志会显示在这里"
                )
            } else {
                logListView
            }
        }
        .background(AppColors.background)
        .frame(minWidth: 600, minHeight: 400)
    }
    
    // MARK: - 工具栏
    private var toolbarView: some View {
        HStack(spacing: AppSpacing.md) {
            // 搜索框
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12))
                    .foregroundColor(AppColors.tertiaryText)
                TextField("搜索 SQL...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(AppColors.tertiaryText)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, AppSpacing.sm)
            .padding(.vertical, AppSpacing.xs)
            .background(AppColors.tertiaryBackground)
            .cornerRadius(AppRadius.sm)
            .frame(maxWidth: 300)
            
            // 连接筛选
            Picker("连接", selection: $selectedConnectionId) {
                ForEach(uniqueConnections, id: \.name) { connection in
                    Text(connection.name)
                        .tag(connection.id)
                }
            }
            .frame(width: 150)
            
            // 状态筛选
            Picker("状态", selection: Binding(
                get: {
                    if showSuccessOnly { return "success" }
                    else if showErrorsOnly { return "error" }
                    else { return "all" }
                },
                set: { value in
                    showSuccessOnly = value == "success"
                    showErrorsOnly = value == "error"
                }
            )) {
                Text("全部").tag("all")
                Text("成功").tag("success")
                Text("失败").tag("error")
            }
            .frame(width: 100)
            
            Spacer()
            
            // 统计信息
            Text("\(filteredLogs.count) 条记录")
                .font(.system(size: 11))
                .foregroundColor(AppColors.secondaryText)
            
            // 导出按钮
            Button {
                exportLogs()
            } label: {
                Image(systemName: "square.and.arrow.up")
            }
            .buttonStyle(AppIconButtonStyle())
            .help("导出日志")
            
            // 清除按钮
            Button {
                logger.clearLogs()
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(AppIconButtonStyle())
            .help("清除所有日志")
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.sm)
        .background(AppColors.secondaryBackground)
    }
    
    // MARK: - 日志列表
    private var logListView: some View {
        ScrollView {
            LazyVStack(spacing: 1) {
                ForEach(filteredLogs) { log in
                    SQLLogRow(log: log)
                }
            }
            .padding(.vertical, AppSpacing.xs)
        }
    }
    
    // MARK: - 导出
    private func exportLogs() {
        let text = logger.exportAsText()
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = "sql_history_\(Date().timeIntervalSince1970).txt"
        
        if panel.runModal() == .OK, let url = panel.url {
            try? text.write(to: url, atomically: true, encoding: .utf8)
        }
    }
}

// MARK: - 日志行视图
struct SQLLogRow: View {
    let log: SQLLogEntry
    @State private var isExpanded: Bool = false
    @State private var isCopied: Bool = false
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            // 主行
            HStack(spacing: AppSpacing.sm) {
                // 状态图标
                Image(systemName: log.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(log.success ? AppColors.success : AppColors.error)
                    .font(.system(size: 12))
                
                // 时间
                Text(dateFormatter.string(from: log.timestamp))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(AppColors.secondaryText)
                
                // 数据库类型
                Text(log.databaseType)
                    .font(.system(size: 10))
                    .padding(.horizontal, AppSpacing.xs)
                    .padding(.vertical, 1)
                    .background(databaseTypeColor.opacity(0.15))
                    .foregroundColor(databaseTypeColor)
                    .cornerRadius(AppRadius.sm)
                
                // 连接名称
                Text(log.connectionName)
                    .font(.system(size: 11))
                    .foregroundColor(AppColors.secondaryText)
                    .lineLimit(1)
                
                Spacer()
                
                // 执行时间
                Text(String(format: "%.3fs", log.duration))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(durationColor)
                
                // 行数
                if let rowCount = log.rowCount {
                    Text("\(rowCount) 行")
                        .font(.system(size: 11))
                        .foregroundColor(AppColors.secondaryText)
                }
                
                // 复制按钮
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(log.sql, forType: .string)
                    withAnimation {
                        isCopied = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        withAnimation {
                            isCopied = false
                        }
                    }
                } label: {
                    Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 11))
                        .foregroundColor(isCopied ? AppColors.success : AppColors.secondaryText)
                }
                .buttonStyle(.plain)
                .help("复制 SQL")
                
                // 展开/收起
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                } label: {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10))
                        .foregroundColor(AppColors.secondaryText)
                }
                .buttonStyle(.plain)
            }
            
            // SQL 预览（单行）
            if !isExpanded {
                Text(log.sql.replacingOccurrences(of: "\n", with: " "))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(AppColors.primaryText)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            
            // 展开的 SQL
            if isExpanded {
                ScrollView(.horizontal, showsIndicators: false) {
                    Text(log.sql)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(AppColors.primaryText)
                        .textSelection(.enabled)
                }
                .padding(AppSpacing.sm)
                .background(AppColors.tertiaryBackground)
                .cornerRadius(AppRadius.sm)
                
                // 错误信息
                if let error = log.errorMessage {
                    HStack(spacing: AppSpacing.xs) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(AppColors.error)
                            .font(.system(size: 11))
                        Text(error)
                            .font(.system(size: 11))
                            .foregroundColor(AppColors.error)
                    }
                    .padding(AppSpacing.sm)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppColors.error.opacity(0.08))
                    .cornerRadius(AppRadius.sm)
                }
            }
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.sm)
        .background(log.success ? Color.clear : AppColors.error.opacity(0.03))
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            // 双击复制 SQL
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(log.sql, forType: .string)
        }
    }
    
    private var databaseTypeColor: Color {
        switch log.databaseType.lowercased() {
        case "mysql": return AppColors.warning
        case "sqlite": return AppColors.accent
        case "postgresql": return Color.teal
        default: return AppColors.secondaryText
        }
    }
    
    private var durationColor: Color {
        if log.duration < 0.1 { return AppColors.success }
        else if log.duration < 1.0 { return AppColors.warning }
        else { return AppColors.error }
    }
}

// MARK: - 日志窗口
struct SQLLogWindow: View {
    var body: some View {
        SQLLogView()
            .frame(minWidth: 800, minHeight: 500)
    }
}

#Preview {
    SQLLogView()
}
