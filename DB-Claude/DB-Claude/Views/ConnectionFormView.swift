import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct ConnectionFormView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext

    var editingConnection: Connection?

    @State private var name = ""
    @State private var type: DatabaseType = .sqlite
    @State private var host = "localhost"
    @State private var port = "3306"
    @State private var username = "root"
    @State private var password = ""
    @State private var databaseName = ""
    @State private var filePath = ""
    @State private var isImporting = false

    private var isEditMode: Bool { editingConnection != nil }
    private var isSQLite: Bool { type == .sqlite }

    var body: some View {
        VStack(spacing: 0) {
            // 内容区域
            ScrollView {
                VStack(spacing: AppSpacing.lg) {
                    // 连接名称
                    FormField("连接名称") {
                        TextField("My Database", text: $name)
                    }
                    
                    // 数据库类型选择（卡片式）
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Text("数据库类型").font(.system(size: 12, weight: .medium)).foregroundColor(AppColors.secondaryText)
                        
                        HStack(spacing: AppSpacing.sm) {
                            ForEach(DatabaseType.allCases) { dbType in
                                DatabaseTypeCard(
                                    type: dbType,
                                    isSelected: type == dbType,
                                    disabled: isEditMode
                                ) { type = dbType }
                            }
                        }
                    }
                    
                    Divider().padding(.vertical, AppSpacing.xs)
                    
                    // 配置区域
                    if isSQLite {
                        sqliteConfig
                    } else {
                        serverConfig
                    }
                }
                .padding(AppSpacing.lg)
            }
            
            Divider()
            
            // 底部按钮
            HStack {
                Button("取消") { dismiss() }
                    .keyboardShortcut(.escape, modifiers: [])
                Spacer()
                Button(isEditMode ? "更新" : "保存", action: saveConnection)
                    .keyboardShortcut(.return, modifiers: [])
                    .buttonStyle(.borderedProminent)
                    .disabled(name.isEmpty || (isSQLite && filePath.isEmpty))
            }
            .padding(AppSpacing.md)
        }
        .frame(width: 400, height: isSQLite ? 300 : 420)
        .background(AppColors.background)
        .fileImporter(isPresented: $isImporting, allowedContentTypes: [.database, .data], allowsMultipleSelection: false) { result in
            if case .success(let urls) = result, let url = urls.first {
                filePath = url.path
            }
        }
        .onAppear(perform: loadConnection)
    }
    
    // MARK: - SQLite 配置
    
    @ViewBuilder private var sqliteConfig: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("数据库文件").font(.system(size: 12, weight: .medium)).foregroundColor(AppColors.secondaryText)
            
            HStack(spacing: AppSpacing.sm) {
                // 文件路径显示
                HStack {
                    Image(systemName: filePath.isEmpty ? "doc.badge.plus" : "doc.fill")
                        .foregroundColor(filePath.isEmpty ? AppColors.tertiaryText : AppColors.accent)
                    Text(filePath.isEmpty ? "选择 .db 或 .sqlite 文件" : URL(fileURLWithPath: filePath).lastPathComponent)
                        .foregroundColor(filePath.isEmpty ? AppColors.tertiaryText : AppColors.primaryText)
                        .lineLimit(1)
                    Spacer()
                }
                .font(.system(size: 13))
                .padding(AppSpacing.sm)
                .frame(maxWidth: .infinity)
                .background(AppColors.secondaryBackground)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
                
                Button("浏览...") { isImporting = true }
            }
            
            if !filePath.isEmpty {
                Text(filePath)
                    .font(.system(size: 11))
                    .foregroundColor(AppColors.tertiaryText)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
    }
    
    // MARK: - 服务器配置
    
    @ViewBuilder private var serverConfig: some View {
        VStack(spacing: AppSpacing.md) {
            // 主机 & 端口（并排）
            HStack(spacing: AppSpacing.sm) {
                FormField("主机") { TextField("localhost", text: $host) }
                FormField("端口", width: 80) { TextField("3306", text: $port) }
            }
            
            // 用户名 & 密码（并排）
            HStack(spacing: AppSpacing.sm) {
                FormField("用户名") { TextField("root", text: $username) }
                FormField("密码") { SecureField("可选", text: $password) }
            }
            
            // 数据库名
            FormField("数据库名称（可选）") { TextField("留空则显示所有数据库", text: $databaseName) }
        }
    }
    
    // MARK: - Actions
    
    private func loadConnection() {
        guard let conn = editingConnection else { return }
        name = conn.name
        type = conn.type
        host = conn.host ?? "localhost"
        port = String(conn.port ?? 3306)
        username = conn.username ?? "root"
        password = conn.password ?? ""
        databaseName = conn.databaseName ?? ""
        filePath = conn.filePath ?? ""
    }

    private func saveConnection() {
        let serverConfig = isSQLite ? (nil, nil, nil, nil, nil) : (host, Int(port), username, password.isEmpty ? nil : password, databaseName)
        
        if let conn = editingConnection {
            conn.name = name
            conn.host = serverConfig.0
            conn.port = serverConfig.1
            conn.username = serverConfig.2
            conn.password = serverConfig.3
            conn.databaseName = serverConfig.4
            conn.filePath = isSQLite ? filePath : nil
            conn.updatedAt = Date()
        } else {
            modelContext.insert(Connection(
                name: name, type: type,
                host: serverConfig.0, port: serverConfig.1,
                username: serverConfig.2, password: serverConfig.3,
                databaseName: serverConfig.4, filePath: isSQLite ? filePath : nil
            ))
        }
        dismiss()
    }
}

// MARK: - Components

/// 数据库类型卡片
private struct DatabaseTypeCard: View {
    let type: DatabaseType
    let isSelected: Bool
    let disabled: Bool
    let action: () -> Void
    
    private var icon: String {
        switch type {
        case .sqlite: return "doc.circle.fill"
        case .mysql: return "server.rack"
        case .postgresql: return "server.rack"
        }
    }
    
    private var color: Color {
        switch type {
        case .sqlite: return .blue
        case .mysql: return .orange
        case .postgresql: return .cyan
        }
    }
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: AppSpacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(isSelected ? color : AppColors.tertiaryText)
                Text(type.rawValue)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(isSelected ? AppColors.primaryText : AppColors.secondaryText)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppSpacing.sm)
            .background(isSelected ? color.opacity(0.1) : AppColors.secondaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.md)
                    .stroke(isSelected ? color : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled && !isSelected ? 0.5 : 1)
    }
}

/// 表单字段（垂直布局：标签在上，输入框在下）
private struct FormField<Content: View>: View {
    let label: String
    let width: CGFloat?
    let content: Content
    
    init(_ label: String, width: CGFloat? = nil, @ViewBuilder content: () -> Content) {
        self.label = label
        self.width = width
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(AppColors.secondaryText)
            content
                .textFieldStyle(.roundedBorder)
        }
        .frame(width: width, alignment: .leading)
        .frame(maxWidth: width == nil ? .infinity : nil, alignment: .leading)
    }
}
