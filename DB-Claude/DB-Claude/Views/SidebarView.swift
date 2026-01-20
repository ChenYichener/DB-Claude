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
    @State private var showingAddSheet = false
    @State private var editingConnection: Connection?

    var body: some View {
        List(selection: $selection) {
            Section("Connections") {
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
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showingAddSheet = true }) {
                    Label("Add Connection", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            ConnectionFormView()
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
                modelContext.delete(connections[index])
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

    // 连接行视图 - 扁平化设计
    private var connectionRow: some View {
        HStack(spacing: AppSpacing.sm) {
            // 展开/折叠指示器
            Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(AppColors.tertiaryText)
                .frame(width: 12)
            
            // 图标
            Image(systemName: SidebarIcons.database(for: connection.type))
                .font(.system(size: 14))
                .foregroundColor(iconColor)
            
            // 名称
            Text(connection.name)
                .font(.system(size: 13, weight: highlightState == .selected ? .semibold : .regular))
                .lineLimit(1)
            
            Spacer()
            
            // 状态指示器
            if highlightState == .childSelected {
                Circle()
                    .fill(AppColors.accent)
                    .frame(width: 6, height: 6)
            }
        }
        .padding(.vertical, AppSpacing.sm)
        .padding(.horizontal, AppSpacing.sm)
        .background(connectionRowBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
        .onTapGesture(count: 2) {
            withAnimation(.easeInOut(duration: 0.2)) {
                isExpanded.toggle()
            }
        }
        .onTapGesture(count: 1) {
            withAnimation(.easeInOut(duration: 0.15)) {
                if selection != .connection(connection) {
                    selection = .connection(connection)
                }
            }
        }
        .foregroundColor(foregroundColorForState)
        .contextMenu {
            Button(action: {
                editingConnection = connection
            }) {
                Label("编辑连接", systemImage: "pencil")
            }

            Divider()

            Button(role: .destructive, action: {
                withAnimation {
                    modelContext.delete(connection)
                    selection = nil
                }
            }) {
                Label("删除", systemImage: "trash")
            }
        }
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
                    }
                } else {
                     await MainActor.run { self.isLoading = false }
                }
            } catch {
                print("Error loading databases: \(error)")
                await MainActor.run { self.isLoading = false }
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
                .font(.system(size: 12))
                .foregroundColor(isSelected ? .white : AppColors.secondaryText)
            
            Text(name)
                .font(.system(size: 12, weight: isSelected ? .medium : .regular))
                .lineLimit(1)
            
            Spacer()
        }
        .padding(.vertical, AppSpacing.xs + 2)
        .padding(.horizontal, AppSpacing.sm)
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
