import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var tabManager = TabManager()
    @State private var inspectorIsPresented: Bool = false // 默认隐藏

    // Sidebar state
    @State private var selection: SidebarSelection?
    @State private var selectedTable: String? // For navigation link
    @State private var tables: [TableInfo] = []
    @State private var tableSearchText: String = "" // 表搜索文本
    
    // 过滤后的表列表
    private var filteredTables: [TableInfo] {
        if tableSearchText.isEmpty {
            return tables
        }
        return tables.filter { $0.name.localizedCaseInsensitiveContains(tableSearchText) }
    }

    // Inspector 状态
    @State private var inspectorContent: InspectorContent = .history

    // Driver state
    @State private var currentDriver: (any DatabaseDriver)?
    @State private var errorMessage: String?

    // Inspector 内容类型
    enum InspectorContent: Equatable {
        case history
        case ddl(table: String, content: String)
        
        var isHistory: Bool {
            if case .history = self { return true }
            return false
        }
    }
    
    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $selection)
                .navigationSplitViewColumnWidth(min: 160, ideal: 200)
        } content: {
            if let selection = selection {
                switch selection {
                case .connection(let connection):
                    VStack {
                        Text("Connection: \(connection.name)")
                            .font(.headline)
                        
                        Divider()
                        
                        Button("New Query Tab") {
                            tabManager.addQueryTab(connectionId: connection.id)
                        }
                        .padding()
                        
                        // List existing tabs for this connection?
                        // Or just general info
                        Spacer()
                    }
                    .padding()
                    
                case .database(let connection, let dbName):
                    VStack(spacing: 0) {
                        // 搜索框
                        HStack(spacing: AppSpacing.sm) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 12))
                                .foregroundColor(AppColors.tertiaryText)
                            
                            TextField("搜索表...", text: $tableSearchText)
                                .textFieldStyle(.plain)
                                .font(.system(size: 12))
                            
                            if !tableSearchText.isEmpty {
                                Button {
                                    tableSearchText = ""
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 12))
                                        .foregroundColor(AppColors.tertiaryText)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.vertical, AppSpacing.sm)
                        .background(AppColors.secondaryBackground)
                        
                        // 表头（显示过滤后的数量）
                        HStack {
                            Text("表 (\(filteredTables.count)\(tableSearchText.isEmpty ? "" : "/\(tables.count)"))")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(AppColors.secondaryText)
                            Spacer()
                        }
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.vertical, AppSpacing.xs)
                        .background(AppColors.tertiaryBackground)
                        
                        // 错误信息
                        if let error = errorMessage {
                            AppErrorState(message: error)
                        }
                        
                        // 表列表（使用过滤后的列表）
                        if filteredTables.isEmpty && !tableSearchText.isEmpty {
                            AppEmptyState(
                                icon: "magnifyingglass",
                                title: "未找到匹配的表"
                            )
                        } else {
                            ScrollView {
                                LazyVStack(alignment: .leading, spacing: 2) {
                                    ForEach(filteredTables) { tableInfo in
                                        TableRow(
                                            tableInfo: tableInfo,
                                            isSelected: selectedTable == tableInfo.name,
                                            onSingleTap: {
                                                selectedTable = tableInfo.name
                                                Task { await showDDLForTable(tableInfo.name, connection: connection) }
                                            },
                                            onDoubleTap: {
                                                tabManager.openDataTab(table: tableInfo.name, connectionId: connection.id)
                                            }
                                        )
                                    }
                                }
                                .padding(AppSpacing.sm)
                            }
                        }
                    }
                    .background(AppColors.background)
                    .navigationTitle(dbName)
                    .onChange(of: dbName) { _, _ in
                        // 切换数据库时清空搜索
                        tableSearchText = ""
                    }
                    .task(id: dbName) {
                        await loadTables(for: connection, database: dbName)
                    }
                    .toolbar {
                        Button(action: {
                            tabManager.addQueryTab(connectionId: connection.id)
                        }) {
                            Label("New Query", systemImage: "plus.square.on.square")
                        }
                        .keyboardShortcut("t", modifiers: .command)
                        
                        Button(action: {
                            // 如果已经显示历史记录，则切换面板显示状态
                            // 否则切换到历史记录并打开面板
                            if inspectorContent.isHistory && inspectorIsPresented {
                                inspectorIsPresented = false
                            } else {
                                inspectorContent = .history
                                inspectorIsPresented = true
                            }
                        }) {
                            Label("History", systemImage: "clock")
                        }
                    }
                }
            } else {
                Text("Select a connection")
            }
        } detail: {
            HSplitView {
                // 主内容区
                VStack(spacing: 0) {
                    // 双行 Tab Bar
                    if !tabManager.tabs.isEmpty {
                        VStack(spacing: 0) {
                            // 第一行：数据表 tabs
                            if !tabManager.dataTabs.isEmpty {
                                TabBarRow(
                                    tabManager: tabManager,
                                    tabType: .data,
                                    iconName: iconName,
                                    label: "数据表"
                                )
                            }

                            // 第二行：查询 tabs
                            TabBarRow(
                                tabManager: tabManager,
                                tabType: .query,
                                iconName: iconName,
                                label: "查询",
                                showAddButton: true,
                                onAddTab: {
                                    if let sel = selection {
                                        let conn = extractConnection(from: sel)
                                        tabManager.addQueryTab(connectionId: conn.id)
                                    }
                                }
                            )
                        }
                        .background(AppColors.background)

                        Divider()

                        // Tab Content - 使用 ZStack 保持所有 tab 存活，避免状态丢失
                        ZStack {
                            ForEach(tabManager.tabs) { tab in
                                TabContentWrapper(
                                    tab: tab,
                                    currentDriver: currentDriver,
                                    connectionId: tab.connectionId
                                )
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                                .opacity(tabManager.activeTabId == tab.id ? 1 : 0)
                                .allowsHitTesting(tabManager.activeTabId == tab.id)
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ContentUnavailableView("Start by selecting a table or opening a query", systemImage: "arrow.left")
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .layoutPriority(1) // 主内容区优先占据空间
                
                // 右侧 Inspector 面板
                if inspectorIsPresented {
                    VStack(spacing: 0) {
                        switch inspectorContent {
                        case .history:
                            HistoryInspectorView(
                                onSelectSQL: { sql in
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(sql, forType: .string)
                                },
                                connectionID: extractConnectionID(from: selection)
                            )
                        case .ddl(let table, let content):
                            DDLInspectorView(tableName: table, ddl: content)
                        }
                    }
                    .frame(minWidth: 220, maxWidth: 500)
                }
            }
        }
        // MARK: - 快捷键：Command+数字切换查询标签页
        .background(
            Group {
                // Command+1 切换到第1个查询标签页
                Button(action: { switchToQueryTab(index: 0) }) { EmptyView() }
                    .keyboardShortcut("1", modifiers: .command)
                
                // Command+2 切换到第2个查询标签页
                Button(action: { switchToQueryTab(index: 1) }) { EmptyView() }
                    .keyboardShortcut("2", modifiers: .command)
                
                // Command+3 切换到第3个查询标签页
                Button(action: { switchToQueryTab(index: 2) }) { EmptyView() }
                    .keyboardShortcut("3", modifiers: .command)
                
                // Command+4 切换到第4个查询标签页
                Button(action: { switchToQueryTab(index: 3) }) { EmptyView() }
                    .keyboardShortcut("4", modifiers: .command)
                
                // Command+5 切换到第5个查询标签页
                Button(action: { switchToQueryTab(index: 4) }) { EmptyView() }
                    .keyboardShortcut("5", modifiers: .command)
            }
            .opacity(0)
        )
    }
    
    /// 切换到指定索引的查询标签页
    private func switchToQueryTab(index: Int) {
        let queryTabs = tabManager.queryTabs
        if index < queryTabs.count {
            tabManager.activeTabId = queryTabs[index].id
        }
    }
    
    private func iconName(for type: TabType) -> String {
        switch type {
        case .query: return "terminal"
        case .structure: return "tablecells"
        case .data: return "tablecells.fill"
        }
    }
    
    private func extractConnection(from selection: SidebarSelection) -> Connection {
        switch selection {
        case .connection(let c): return c
        case .database(let c, _): return c
        }
    }
    
    private func extractConnectionID(from selection: SidebarSelection?) -> UUID? {
        guard let s = selection else { return nil }
        return extractConnection(from: s).id
    }
    
    private func loadTables(for connection: Connection, database: String) async {
        tables = []
        errorMessage = nil
        selectedTable = nil
        inspectorContent = .history // 切换到历史记录

        if let driver = currentDriver {
            await driver.disconnect()
        }
        currentDriver = nil

        do {
            guard let driver = createDriver(for: connection) else { return }
            currentDriver = driver
            try await driver.connect()
            tables = try await driver.fetchTablesWithInfo()
            
            // 加载成功后，如果当前没有该连接的查询标签页，自动创建一个
            await MainActor.run {
                let hasQueryTab = tabManager.tabs.contains { tab in
                    tab.connectionId == connection.id && tab.type == .query
                }
                if !hasQueryTab {
                    tabManager.addQueryTab(connectionId: connection.id)
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // 显示表的 DDL
    private func showDDLForTable(_ table: String, connection: Connection) async {
        guard let driver = currentDriver else {
            // 如果当前没有驱动，创建一个临时的
            guard let newDriver = createDriver(for: connection) else { return }
            do {
                try await newDriver.connect()
                let ddl = try await newDriver.getDDL(for: table)
                await MainActor.run {
                    inspectorContent = .ddl(table: table, content: ddl)
                }
                await newDriver.disconnect()
            } catch {
                print("Error loading DDL: \(error)")
            }
            return
        }

        do {
            let ddl = try await driver.getDDL(for: table)
            await MainActor.run {
                inspectorContent = .ddl(table: table, content: ddl)
                if !inspectorIsPresented {
                    inspectorIsPresented = true
                }
            }
        } catch {
            print("Error loading DDL: \(error)")
        }
    }

    private func createDriver(for connection: Connection) -> (any DatabaseDriver)? {
        switch connection.type {
        case .sqlite:
            if let path = connection.filePath, !path.isEmpty {
                return SQLiteDriver(path: path, connectionId: connection.id, connectionName: connection.name)
            }
        case .mysql:
            return RealMySQLDriver(connection: connection)
        default: break
        }
        return nil
    }
}

// Wrapper to help resolve Connection from ID if needed,
// OR we just use the current driver if it matches?
// Real app would have a robust ConnectionManager service.
struct TabContentWrapper: View {
    let tab: WorkspaceTab
    let currentDriver: (any DatabaseDriver)?
    let connectionId: UUID

    @Query private var connections: [Connection]
    @State private var tabDriver: (any DatabaseDriver)?

    var body: some View {
        if let connection = connections.first(where: { $0.id == connectionId }) {
            switch tab.type {
            case .query:
                QueryEditorView(connection: connection)
            case .structure(let table):
                if let driver = currentDriver {
                    StructureView(table: table, driver: driver)
                } else {
                    Text("Driver not ready").foregroundStyle(.secondary)
                }
            case .data(let table):
                DataTabView(
                    table: table,
                    connection: connection,
                    initialDriver: currentDriver
                )
            }
        } else {
            Text("Connection not found").foregroundStyle(.red)
        }
    }
}

// Data tab 的包装视图，负责创建和管理驱动
struct DataTabView: View {
    let table: String
    let connection: Connection
    let initialDriver: (any DatabaseDriver)?

    @State private var driver: (any DatabaseDriver)?
    @State private var isLoading: Bool = true
    @State private var errorMessage: String?

    var body: some View {
        if isLoading {
            VStack {
                HStack(spacing: AppSpacing.sm) {
                    ProgressView()
                        .controlSize(.small)
                    Text("连接中...")
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.secondaryText)
                }
                .padding(AppSpacing.md)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .task {
                await setupDriver()
            }
        } else if let error = errorMessage {
            VStack {
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(AppColors.error)
                    Text(error)
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.error)
                }
                .padding(AppSpacing.md)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else if let driver = driver {
            TableDataView(table: table, driver: driver)
        } else {
            VStack {
                Text("无法连接到数据库")
                    .foregroundColor(AppColors.secondaryText)
                    .padding(AppSpacing.md)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private func setupDriver() async {
        // 如果有可用的驱动，直接使用
        if let existingDriver = initialDriver {
            await MainActor.run {
                self.driver = existingDriver
                self.isLoading = false
            }
            return
        }

        // 否则创建新驱动
        guard let newDriver = createDriver(for: connection) else {
            await MainActor.run {
                self.errorMessage = "无法创建数据库驱动"
                self.isLoading = false
            }
            return
        }

        do {
            try await newDriver.connect()
            await MainActor.run {
                self.driver = newDriver
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }

    private func createDriver(for connection: Connection) -> (any DatabaseDriver)? {
        switch connection.type {
        case .sqlite:
            if let path = connection.filePath, !path.isEmpty {
                return SQLiteDriver(path: path, connectionId: connection.id, connectionName: connection.name)
            } else {
                return nil
            }
        case .mysql:
            return RealMySQLDriver(connection: connection)
        case .postgresql:
            return nil // TODO: 实现 PostgreSQL 驱动
        }
    }
}

// MARK: - Tab Bar 行视图
struct TabBarRow: View {
    @Bindable var tabManager: TabManager
    let tabType: TabRowType
    let iconName: (TabType) -> String
    var label: String = ""
    var showAddButton: Bool = false
    var onAddTab: (() -> Void)?

    enum TabRowType {
        case data
        case query
    }

    private var tabs: [WorkspaceTab] {
        switch tabType {
        case .data: return tabManager.dataTabs
        case .query: return tabManager.queryTabs
        }
    }

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            // 行标签
            if !label.isEmpty {
                Text(label)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(AppColors.tertiaryText)
                    .frame(width: 40)
                    .padding(.leading, AppSpacing.sm)
            }

            // 滚动的 tabs
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppSpacing.sm) {
                    ForEach(tabs) { tab in
                        TabItemView(
                            tab: tab,
                            isActive: tabManager.activeTabId == tab.id,
                            iconName: iconName(tab.type),
                            onSelect: {
                                tabManager.activeTabId = tab.id
                            },
                            onClose: {
                                tabManager.closeTab(id: tab.id)
                            },
                            onRename: tab.isRenamable ? { newName in
                                tabManager.renameTab(id: tab.id, newTitle: newName)
                            } : nil
                        )
                    }
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, AppSpacing.xs)
            }

            // 添加按钮
            if showAddButton {
                Button {
                    onAddTab?()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(AppColors.secondaryText)
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(AppIconButtonStyle(size: 24))
                .padding(.trailing, AppSpacing.sm)
            }
        }
        .frame(height: 36)
        .background(.ultraThinMaterial)  // 毛玻璃效果
    }
}

// Tab 项视图 - 扁平化设计，支持重命名
struct TabItemView: View {
    let tab: WorkspaceTab
    let isActive: Bool
    let iconName: String
    let onSelect: () -> Void
    let onClose: () -> Void
    var onRename: ((String) -> Void)?

    @State private var isHovering = false
    @State private var isCloseHovering = false
    @State private var isEditing = false
    @State private var editingTitle = ""

    var body: some View {
        HStack(spacing: AppSpacing.xs) {
            Image(systemName: iconName)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(isActive ? .white : AppColors.secondaryText)

            if isEditing {
                TextField("", text: $editingTitle, onCommit: {
                    if !editingTitle.isEmpty {
                        onRename?(editingTitle)
                    }
                    isEditing = false
                })
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .frame(minWidth: 50, maxWidth: 100)
                .onExitCommand {
                    isEditing = false
                }
            } else {
                Text(tab.title)
                    .font(.system(size: 12, weight: isActive ? .medium : .regular))
                    .lineLimit(1)
            }

            Spacer(minLength: 20)  // 为关闭按钮留出空间
        }
        .padding(.vertical, AppSpacing.xs)
        .padding(.horizontal, AppSpacing.sm)
        .background(tabBackground)
        .foregroundColor(isActive ? .white : AppColors.primaryText)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(isActive ? Color.clear : AppColors.border.opacity(0.5), lineWidth: 1)
        )
        .overlay(alignment: .trailing) {
            // 关闭按钮 - 使用 overlay 叠加，不参与布局
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundColor(closeButtonColor)
                    .frame(width: 16, height: 16)
                    .background(
                        Circle()
                            .fill(isCloseHovering ? closeHoverBackground : Color.clear)
                    )
                    .scaleEffect(isCloseHovering ? 1.1 : 1.0)
            }
            .buttonStyle(.plain)
            .animation(AppAnimation.bouncy, value: isCloseHovering)
            .onHover { isCloseHovering = $0 }
            .padding(.trailing, AppSpacing.sm)
        }
        .scaleEffect(isHovering && !isActive ? 1.02 : 1.0)
        .animation(AppAnimation.fast, value: isHovering)
        .animation(AppAnimation.medium, value: isActive)
        .shadow(color: isActive ? AppColors.accent.opacity(0.3) : Color.clear, radius: 8, y: 2)
        .onHover { isHovering = $0 }
        .onTapGesture {
            if !isEditing {
                onSelect()
            }
        }
        .contextMenu {
            if onRename != nil {
                Button(action: {
                    editingTitle = tab.title
                    isEditing = true
                }) {
                    Label("重命名", systemImage: "pencil")
                }

                Divider()
            }

            Button(role: .destructive, action: onClose) {
                Label("关闭", systemImage: "xmark")
            }
        }
    }

    private var tabBackground: Color {
        if isActive {
            return AppColors.accent
        } else if isHovering {
            return AppColors.hover
        }
        return AppColors.secondaryBackground.opacity(0.5)
    }

    private var closeButtonColor: Color {
        if isActive {
            return .white.opacity(0.8)
        }
        return isCloseHovering ? AppColors.primaryText : AppColors.tertiaryText
    }

    private var closeHoverBackground: Color {
        isActive ? Color.white.opacity(0.2) : AppColors.pressed
    }
}

// 自定义表行 - 紧凑设计
struct TableRow: View {
    let tableInfo: TableInfo
    let isSelected: Bool
    let onSingleTap: () -> Void
    let onDoubleTap: () -> Void
    
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: AppSpacing.xs) {
            // 表图标
            Image(systemName: "tablecells")
                .font(.system(size: 11))
                .foregroundColor(isSelected ? .white : AppColors.secondaryText)
            
            // 表名
            Text(tableInfo.name)
                .font(.system(size: 12))
                .lineLimit(1)
            
            // 表 comment（淡灰色）
            if let comment = tableInfo.comment, !comment.isEmpty {
                Text(comment)
                    .font(.system(size: 11))
                    .foregroundColor(isSelected ? .white.opacity(0.7) : AppColors.tertiaryText)
                    .lineLimit(1)
            }
            
            Spacer()
        }
        .padding(.vertical, AppSpacing.xxs)
        .padding(.horizontal, AppSpacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.sm)
                .fill(backgroundColor)
        )
        .foregroundColor(isSelected ? .white : AppColors.primaryText)
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
        .onTapGesture(count: 2) {
            onDoubleTap()
        }
        .onTapGesture {
            onSingleTap()
        }
    }
    
    private var backgroundColor: Color {
        if isSelected {
            return AppColors.accent
        }
        return isHovering ? AppColors.hover : Color.clear
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Connection.self, inMemory: true)
}
