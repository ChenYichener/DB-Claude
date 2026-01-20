import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var tabManager = TabManager()
    @State private var inspectorIsPresented: Bool = true // 默认打开

    // Sidebar state
    @State private var selection: SidebarSelection?
    @State private var selectedTable: String? // For navigation link
    @State private var tables: [String] = []
    @State private var tableSearchText: String = "" // 表搜索文本
    
    // 过滤后的表列表
    private var filteredTables: [String] {
        if tableSearchText.isEmpty {
            return tables
        }
        return tables.filter { $0.localizedCaseInsensitiveContains(tableSearchText) }
    }

    // Inspector 状态
    @State private var inspectorContent: InspectorContent = .history

    // Driver state
    @State private var currentDriver: (any DatabaseDriver)?
    @State private var errorMessage: String?

    // Inspector 内容类型
    enum InspectorContent {
        case history
        case ddl(table: String, content: String)
    }
    
    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $selection)
                .navigationSplitViewColumnWidth(min: 200, ideal: 250)
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
                            HStack(spacing: AppSpacing.sm) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(AppColors.error)
                                Text(error)
                                    .font(.system(size: 12))
                                    .foregroundColor(AppColors.error)
                            }
                            .padding(AppSpacing.md)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(AppColors.error.opacity(0.1))
                        }
                        
                        // 表列表（使用过滤后的列表）
                        if filteredTables.isEmpty && !tableSearchText.isEmpty {
                            VStack(spacing: AppSpacing.sm) {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 24, weight: .light))
                                    .foregroundColor(AppColors.tertiaryText)
                                Text("未找到匹配的表")
                                    .font(.system(size: 12))
                                    .foregroundColor(AppColors.secondaryText)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else {
                            ScrollView {
                                LazyVStack(alignment: .leading, spacing: AppSpacing.xxs) {
                                    ForEach(filteredTables, id: \.self) { table in
                                        TableRow(
                                            table: table,
                                            isSelected: selectedTable == table,
                                            onSingleTap: {
                                                selectedTable = table
                                                Task { await showDDLForTable(table, connection: connection) }
                                            },
                                            onDoubleTap: {
                                                tabManager.openDataTab(table: table, connectionId: connection.id)
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
                        
                        Button(action: { inspectorIsPresented.toggle() }) {
                            Label("History", systemImage: "clock")
                        }
                    }
                }
            } else {
                Text("Select a connection")
            }
        } detail: {
            VStack(spacing: 0) {
                // 双行 Tab Bar
                if !tabManager.tabs.isEmpty {
                    VStack(spacing: 0) {
                        // 第一行：数据表 tabs
                        if !tabManager.dataTabs.isEmpty {
                            TabBarRow(
                                tabs: tabManager.dataTabs,
                                activeTabId: tabManager.activeTabId,
                                tabManager: tabManager,
                                iconName: iconName,
                                label: "数据表"
                            )
                        }
                        
                        // 第二行：查询 tabs
                        TabBarRow(
                            tabs: tabManager.queryTabs,
                            activeTabId: tabManager.activeTabId,
                            tabManager: tabManager,
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
                    
                    // Tab Content - 填充剩余空间
                    if let activeId = tabManager.activeTabId,
                       let activeTab = tabManager.tabs.first(where: { $0.id == activeId }) {
                        
                        TabContentWrapper(
                            tab: activeTab, 
                            currentDriver: currentDriver,
                            connectionId: activeTab.connectionId
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    } else {
                        ContentUnavailableView("No Open Tabs", systemImage: "square.dashed")
                    }
                } else {
                    ContentUnavailableView("Start by selecting a table or opening a query", systemImage: "arrow.left")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .inspector(isPresented: $inspectorIsPresented) {
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
        .inspectorColumnWidth(min: 250, ideal: 350, max: 600)
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
            tables = try await driver.fetchTables()
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
    let tabs: [WorkspaceTab]
    let activeTabId: UUID?
    let tabManager: TabManager
    let iconName: (TabType) -> String
    var label: String = ""
    var showAddButton: Bool = false
    var onAddTab: (() -> Void)?
    
    var body: some View {
        HStack(spacing: 0) {
            // 行标签
            if !label.isEmpty {
                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(AppColors.tertiaryText)
                    .frame(width: 40)
                    .padding(.leading, AppSpacing.sm)
            }
            
            // 滚动的 tabs
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppSpacing.xs) {
                    ForEach(tabs) { tab in
                        TabItemView(
                            tab: tab,
                            isActive: activeTabId == tab.id,
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
                .padding(.horizontal, AppSpacing.sm)
            }
            
            // 添加按钮
            if showAddButton {
                Button {
                    onAddTab?()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(AppColors.secondaryText)
                        .frame(width: 24, height: 24)
                        .background(AppColors.hover)
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.sm))
                }
                .buttonStyle(.plain)
                .padding(.trailing, AppSpacing.sm)
            }
        }
        .frame(height: 32)
        .background(AppColors.secondaryBackground.opacity(0.5))
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
        HStack(spacing: 0) {
            // 可点击的标题区域
            HStack(spacing: AppSpacing.xs) {
                Image(systemName: iconName)
                    .font(.system(size: 11, weight: .medium))
                
                if isEditing {
                    TextField("", text: $editingTitle, onCommit: {
                        if !editingTitle.isEmpty {
                            onRename?(editingTitle)
                        }
                        isEditing = false
                    })
                    .textFieldStyle(.plain)
                    .font(.system(size: 12, weight: .medium))
                    .frame(minWidth: 60, maxWidth: 120)
                    .onExitCommand {
                        isEditing = false
                    }
                } else {
                    Text(tab.title)
                        .font(.system(size: 12, weight: isActive ? .medium : .regular))
                        .lineLimit(1)
                }
            }
            .padding(.vertical, AppSpacing.sm)
            .padding(.leading, AppSpacing.md)
            .padding(.trailing, AppSpacing.xs)
            .contentShape(Rectangle())
            .onTapGesture(count: 2) {
                if onRename != nil {
                    editingTitle = tab.title
                    isEditing = true
                }
            }
            .onTapGesture {
                if !isEditing {
                    onSelect()
                }
            }
            
            // 独立的关闭按钮区域
            Image(systemName: "xmark")
                .font(.system(size: 8, weight: .semibold))
                .foregroundColor(closeButtonColor)
                .frame(width: 14, height: 14)
                .background(
                    Circle()
                        .fill(isCloseHovering ? closeHoverBackground : Color.clear)
                )
                .contentShape(Rectangle())
                .onHover { isCloseHovering = $0 }
                .onTapGesture {
                    onClose()
                }
                .padding(.trailing, AppSpacing.sm)
        }
        .background(tabBackground)
        .foregroundColor(isActive ? .white : AppColors.primaryText)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.md)
                .stroke(isActive ? Color.clear : AppColors.border, lineWidth: 1)
        )
        .onHover { isHovering = $0 }
    }
    
    private var tabBackground: Color {
        if isActive {
            return AppColors.accent
        } else if isHovering {
            return AppColors.hover
        }
        return Color.clear
    }
    
    private var closeButtonColor: Color {
        if isActive {
            return .white.opacity(0.7)
        }
        return isCloseHovering ? AppColors.primaryText : AppColors.tertiaryText
    }
    
    private var closeHoverBackground: Color {
        isActive ? Color.white.opacity(0.2) : AppColors.pressed
    }
}

// 自定义表行 - 扁平化设计
struct TableRow: View {
    let table: String
    let isSelected: Bool
    let onSingleTap: () -> Void
    let onDoubleTap: () -> Void
    
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            // 表图标
            Image(systemName: "tablecells")
                .font(.system(size: 12))
                .foregroundColor(isSelected ? .white : AppColors.secondaryText)
            
            // 表名
            Text(table)
                .font(.system(size: 13))
                .lineLimit(1)
            
            Spacer()
            
            // 双击提示（悬停时显示）
            if isHovering && !isSelected {
                Text("双击查看数据")
                    .font(.system(size: 10))
                    .foregroundColor(AppColors.tertiaryText)
            }
        }
        .padding(.vertical, AppSpacing.sm)
        .padding(.horizontal, AppSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.md)
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
