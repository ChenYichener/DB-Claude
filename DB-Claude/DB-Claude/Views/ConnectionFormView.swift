import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct ConnectionFormView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext

    // 可选：正在编辑的连接
    var editingConnection: Connection?

    @State private var name: String = ""
    @State private var type: DatabaseType = .sqlite
    @State private var host: String = "localhost"
    @State private var port: String = "3306"
    @State private var username: String = "root"
    @State private var password: String = ""
    @State private var databaseName: String = ""
    @State private var filePath: String = ""
    @State private var isFilePathError: Bool = false
    @State private var isImporting: Bool = false

    // 是否为编辑模式
    private var isEditMode: Bool {
        editingConnection != nil
    }

    var body: some View {
        VStack(spacing: 0) {
            // 表单内容
            Form {
                // 基础信息
                Section {
                    formField(label: "连接名称", systemImage: "tag") {
                        TextField("输入连接名称", text: $name)
                            .textFieldStyle(.plain)
                    }
                    
                    formField(label: "数据库类型", systemImage: "cylinder") {
                        Picker("", selection: $type) {
                            ForEach(DatabaseType.allCases) { type in
                                Text(type.rawValue).tag(type)
                            }
                        }
                        .labelsHidden()
                        .disabled(isEditMode)
                    }
                } header: {
                    sectionHeader("基础信息")
                }

                if type == .sqlite {
                    // SQLite 配置
                    Section {
                        formField(label: "文件路径", systemImage: "folder") {
                            HStack(spacing: AppSpacing.sm) {
                                TextField("选择数据库文件", text: $filePath)
                                    .textFieldStyle(.plain)
                                
                                Button {
                                    isImporting = true
                                } label: {
                                    Text("浏览")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(AppColors.accent)
                                        .padding(.horizontal, AppSpacing.sm)
                                        .padding(.vertical, AppSpacing.xs)
                                        .background(AppColors.accentSubtle)
                                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.sm))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    } header: {
                        sectionHeader("SQLite 配置")
                    }
                } else {
                    // 服务器配置
                    Section {
                        formField(label: "主机地址", systemImage: "server.rack") {
                            TextField("localhost", text: $host)
                                .textFieldStyle(.plain)
                        }
                        
                        formField(label: "端口", systemImage: "number") {
                            TextField("3306", text: $port)
                                .textFieldStyle(.plain)
                        }
                        
                        formField(label: "用户名", systemImage: "person") {
                            TextField("root", text: $username)
                                .textFieldStyle(.plain)
                        }
                        
                        formField(label: "密码", systemImage: "key") {
                            SecureField("输入密码", text: $password)
                                .textFieldStyle(.plain)
                        }
                        
                        formField(label: "数据库", systemImage: "cylinder.split.1x2") {
                            TextField("可选", text: $databaseName)
                                .textFieldStyle(.plain)
                        }
                    } header: {
                        sectionHeader("服务器配置")
                    }
                }
            }
            .formStyle(.grouped)
        }
        .frame(width: 420, height: type == .sqlite ? 280 : 420)
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: [.database, .data],
            allowsMultipleSelection: false
        ) { result in
            do {
                guard let selectedFile: URL = try result.get().first else { return }
                filePath = selectedFile.path
            } catch {
                print("Error selecting file: \(error.localizedDescription)")
            }
        }
        .onAppear {
            if let conn = editingConnection {
                name = conn.name
                type = conn.type
                host = conn.host ?? "localhost"
                port = String(conn.port ?? 3306)
                username = conn.username ?? "root"
                password = conn.password ?? ""
                databaseName = conn.databaseName ?? ""
                filePath = conn.filePath ?? ""
            }
        }
        .navigationTitle(isEditMode ? "编辑连接" : "新建连接")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("取消") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(isEditMode ? "更新" : "保存") {
                    saveConnection()
                }
                .disabled(name.isEmpty)
            }
        }
    }
    
    // MARK: - 辅助视图
    
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(AppColors.secondaryText)
            .textCase(.uppercase)
    }
    
    private func formField<Content: View>(
        label: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(spacing: AppSpacing.md) {
            Image(systemName: systemImage)
                .font(.system(size: 12))
                .foregroundColor(AppColors.secondaryText)
                .frame(width: 16)
            
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(AppColors.primaryText)
                .frame(width: 70, alignment: .leading)
            
            content()
        }
    }

    private func saveConnection() {
        let portInt = Int(port)

        if let conn = editingConnection {
            // 编辑模式：更新现有连接
            conn.name = name
            conn.host = type == .sqlite ? nil : host
            conn.port = type == .sqlite ? nil : portInt
            conn.username = type == .sqlite ? nil : username
            conn.password = type == .sqlite ? nil : (password.isEmpty ? nil : password)
            conn.databaseName = type == .sqlite ? nil : databaseName
            conn.filePath = type == .sqlite ? filePath : nil
            conn.updatedAt = Date()
        } else {
            // 新建模式：创建新连接
            let newConnection = Connection(
                name: name,
                type: type,
                host: type == .sqlite ? nil : host,
                port: type == .sqlite ? nil : portInt,
                username: type == .sqlite ? nil : username,
                password: type == .sqlite ? nil : (password.isEmpty ? nil : password),
                databaseName: type == .sqlite ? nil : databaseName,
                filePath: type == .sqlite ? filePath : nil
            )

            modelContext.insert(newConnection)
        }
        dismiss()
    }
}
