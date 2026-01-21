import SwiftUI
import SwiftData

enum SidebarSelection: Hashable {
    case connection(Connection)
    case database(Connection, String)
}

// 连接高亮状态
enum ConnectionHighlightState {
    case none           // 无高亮
    case selected       // 选中连接
    case childSelected  // 选中了子数据库
}

// MARK: - 侧边栏图标配置
private enum SidebarIcons {
    static func database(for type: DatabaseType) -> String {
        switch type {
        case .sqlite: return "cylinder.split.1x2"
        case .mysql: return "cylinder.split.1x2.fill"
        case .postgresql: return "cylinder"
        }
    }
    
    static let folder = "folder"
    static let table = "tablecells"
}

struct SidebarView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var connections: [Connection]
    @Binding var selection: SidebarSelection?
    @Binding var showingAddConnection: Bool  // 由 ContentView 传入，菜单栏也可控制
    @State private var editingConnection: Connection?

    var body: some View {
        VStack(spacing: 0) {
            // 渐变头部区域（更紧凑）
            VStack(alignment: .leading, spacing: 4) {
                Text("DB-Claude")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)

                Text("\(connections.count) 个连接")
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.8))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.lg)
            .background(
                LinearGradient(
                    colors: [
                        Color(hex: "667EEA"),  // 蓝紫色
                        Color(hex: "764BA2")   // 紫色
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )

            // 连接列表
            List(selection: $selection) {
                Section {
                    ForEach(connections) { connection in
                        ConnectionRow(
                            connection: connection,
                            selection: $selection,
                            editingConnection: $editingConnection
                        )
                    }
                    .onDelete(perform: deleteConnections)
                }
            }
            .listStyle(.sidebar)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showingAddConnection = true }) {
                    Label("添加连接", systemImage: "plus")
                }
                .buttonStyle(AppIconButtonStyle())
            }
        }
        .sheet(item: Binding<Connection?>(
            get: { editingConnection },
            set: { if $0 == nil { editingConnection = nil } }
        )) { connection in
            ConnectionFormView(editingConnection: connection)
        }
    }
    
    private func deleteConnections(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                let connection = connections[index]
                // 删除 Keychain 中的密码
                connection.deleteSecurePassword()
                modelContext.delete(connection)
            }
            // Reset selection if deleted
            // Implementation simplified: if selection is related to deleted connection, plain clear
            selection = nil 
        }
    }
}

struct ConnectionRow: View {
    let connection: Connection
    @Binding var selection: SidebarSelection?
    @Binding var editingConnection: Connection?
    @Environment(\.modelContext) private var modelContext

    @State private var isExpanded: Bool = false
    @State private var databases: [String] = []
    @State private var isLoading: Bool = false
    @State private var isHovering: Bool = false
    @State private var isConnected: Bool = false  // 连接状态追踪
    @State private var connectionError: String?   // 连接错误信息

    // 是否选中连接
    private var isConnectionSelected: Bool {
        selection == .connection(connection)
    }

    // 是否选中了该连接下的数据库
    private var isDatabaseInConnectionSelected: Bool {
        if case .database(let c, _) = selection {
            return c.id == connection.id
        }
        return false
    }

    // 最终的高亮状态
    private var highlightState: ConnectionHighlightState {
        if isConnectionSelected {
            return .selected
        } else if isDatabaseInConnectionSelected {
            return .childSelected
        } else {
            return .none
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
            // Connection Row
            connectionRow
            // Children
            if isExpanded {
                if isLoading {
                    HStack {
                        Spacer()
                        ProgressView()
                            .controlSize(.small)
                        Spacer()
                    }
                    .padding(.vertical, AppSpacing.sm)
                } else {
                    VStack(spacing: 0) {
                        ForEach(databases, id: \.self) { dbName in
                            DatabaseRow(
                                name: dbName,
                                isSelected: isDatabaseSelected(dbName),
                                onTap: {
                                    selection = .database(connection, dbName)
                                }
                            )
                        }
                    }
                    .padding(.leading, AppSpacing.lg)
                }
            }
        }
        .onChange(of: isExpanded) { _, expanded in
            if expanded && databases.isEmpty {
                loadDatabases()
            }
        }
    }

    // 连接行视图 - 紧凑设计
    private var connectionRow: some View {
        HStack(spacing: AppSpacing.sm) {
            // 展开/折叠指示器
            Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(AppColors.tertiaryText)
                .frame(width: 12)
                .animation(AppAnimation.fast, value: isExpanded)

            // 图标
            Image(systemName: SidebarIcons.database(for: connection.type))
                .font(.system(size: 14))
                .foregroundColor(iconColor)
                .symbolRenderingMode(.hierarchical)
                .scaleEffect(isHovering ? 1.05 : 1.0)
                .animation(AppAnimation.bouncy, value: isHovering)

            // 名称
            Text(connection.name)
                .font(.system(size: 12, weight: highlightState == .selected ? .medium : .regular))
                .lineLimit(1)

            Spacer()

            // 连接状态指示器
            connectionStatusIndicator
        }
        .padding(.vertical, AppSpacing.xs)
        .padding(.horizontal, AppSpacing.sm)
        .background(connectionRowBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
        .scaleEffect(isHovering && highlightState == .none ? 1.01 : 1.0)
        .animation(AppAnimation.fast, value: isHovering)
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
        .onTapGesture(count: 2) {
            withAnimation(AppAnimation.medium) {
                isExpanded.toggle()
            }
        }
        .onTapGesture(count: 1) {
            withAnimation(AppAnimation.fast) {
                if selection != .connection(connection) {
                    selection = .connection(connection)
                }
            }
        }
        .foregroundColor(foregroundColorForState)
        .contextMenu {
            // 连接操作
            Button(action: {
                reconnect()
            }) {
                Label("重新连接", systemImage: "arrow.clockwise")
            }

            Button(action: {
                closeConnection()
            }) {
                Label("关闭连接", systemImage: "xmark.circle")
            }
            .disabled(!isConnected && databases.isEmpty)

            Divider()

            Button(action: {
                editingConnection = connection
            }) {
                Label("编辑连接", systemImage: "pencil")
            }

            Divider()

            Button(role: .destructive, action: {
                withAnimation {
                    // 删除 Keychain 中的密码
                    connection.deleteSecurePassword()
                    modelContext.delete(connection)
                    selection = nil
                }
            }) {
                Label("删除连接", systemImage: "trash")
            }
        }
    }
    
    // 连接状态指示器视图
    @ViewBuilder
    private var connectionStatusIndicator: some View {
        if isLoading {
            // 正在连接中
            ProgressView()
                .controlSize(.mini)
                .scaleEffect(0.7)
        } else if connectionError != nil {
            // 连接错误
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 10))
                .foregroundColor(AppColors.error)
                .help(connectionError ?? "连接错误")
        } else if isConnected {
            // 已连接
            Circle()
                .fill(AppColors.success)
                .frame(width: 6, height: 6)
                .help("已连接")
        } else if highlightState == .childSelected {
            // 选中了子数据库
            Circle()
                .fill(AppColors.accent)
                .frame(width: 6, height: 6)
        }
        // 未连接状态不显示指示器
    }
    
    private var iconColor: Color {
        switch highlightState {
        case .selected: return .white
        case .childSelected: return AppColors.accent
        case .none: return AppColors.secondaryText
        }
    }

    // 连接行前景色
    private var foregroundColorForState: Color {
        switch highlightState {
        case .selected: return .white
        case .childSelected: return AppColors.primaryText
        case .none: return AppColors.primaryText
        }
    }

    // 连接行背景 - 扁平化，无阴影
    private var connectionRowBackground: Color {
        switch highlightState {
        case .selected:
            return AppColors.accent
        case .childSelected:
            return AppColors.accentSubtle
        case .none:
            return isHovering ? AppColors.hover : Color.clear
        }
    }

    private func isDatabaseSelected(_ dbName: String) -> Bool {
        if case .database(let c, let n) = selection {
            return c.id == connection.id && n == dbName
        }
        return false
    }
    
    private func loadDatabases() {
        isLoading = true
        connectionError = nil
        Task {
            do {
                var driver: DatabaseDriver?
                switch connection.type {
                case .sqlite:
                    if let path = connection.filePath {
                        driver = SQLiteDriver(path: path, connectionId: connection.id, connectionName: connection.name)
                    }
                case .mysql:
                    driver = RealMySQLDriver(connection: connection)
                default:
                    break
                }
                
                if let drv = driver {
                    try await drv.connect()
                    let dbs = try await drv.fetchDatabases()
                    await drv.disconnect()
                    
                    await MainActor.run {
                        self.databases = dbs
                        self.isLoading = false
                        self.isConnected = true
                        self.connectionError = nil
                    }
                } else {
                     await MainActor.run { 
                        self.isLoading = false 
                        self.isConnected = false
                    }
                }
            } catch {
                print("Error loading databases: \(error)")
                await MainActor.run { 
                    self.isLoading = false 
                    self.isConnected = false
                    self.connectionError = error.localizedDescription
                }
            }
        }
    }
    
    // MARK: - 连接操作方法
    
    /// 重新连接 - 重新加载数据库列表
    private func reconnect() {
        withAnimation(.easeInOut(duration: 0.2)) {
            // 清空现有数据
            databases = []
            connectionError = nil
            isConnected = false
            // 重新加载
            loadDatabases()
            // 确保展开以显示结果
            if !isExpanded {
                isExpanded = true
            }
        }
    }
    
    /// 关闭连接 - 断开连接并折叠列表
    private func closeConnection() {
        withAnimation(.easeInOut(duration: 0.2)) {
            // 折叠列表
            isExpanded = false
            // 清空数据库列表
            databases = []
            // 更新连接状态
            isConnected = false
            connectionError = nil
            // 如果当前选中的是这个连接或其子数据库，清除选中
            if case .database(let c, _) = selection, c.id == connection.id {
                selection = nil
            }
        }
    }
}

// MARK: - 数据库行组件 - 扁平化设计
private struct DatabaseRow: View {
    let name: String
    let isSelected: Bool
    let onTap: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: SidebarIcons.folder)
                .font(.system(size: 11))
                .foregroundColor(isSelected ? .white : AppColors.secondaryText)

            Text(name)
                .font(isSelected ? AppTypography.captionMedium : AppTypography.caption)
                .lineLimit(1)

            Spacer()
        }
        .padding(.vertical, AppSpacing.xs)
        .padding(.horizontal, AppSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.sm)
                .fill(backgroundColor)
        )
        .foregroundColor(isSelected ? .white : AppColors.primaryText)
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
        .onTapGesture {
            onTap()
        }
    }
    
    private var backgroundColor: Color {
        if isSelected {
            return AppColors.accent
        }
        return isHovering ? AppColors.hover : Color.clear
    }
}
