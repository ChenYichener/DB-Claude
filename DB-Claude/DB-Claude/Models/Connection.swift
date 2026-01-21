import Foundation
import SwiftData

@Model
final class Connection {
    var id: UUID
    var name: String
    var type: DatabaseType
    
    // Connection Details
    var host: String?
    var port: Int?
    var username: String?
    
    /// 已废弃：密码现在存储在 Keychain 中
    /// 保留此属性用于数据迁移，新密码不再存储在此字段
    @Attribute(.allowsCloudEncryption)
    private(set) var password: String?
    
    var databaseName: String?
    
    // For SQLite
    var filePath: String?
    
    var createdAt: Date
    var updatedAt: Date
    
    init(name: String, type: DatabaseType, host: String? = nil, port: Int? = nil, username: String? = nil, password: String? = nil, databaseName: String? = nil, filePath: String? = nil) {
        self.id = UUID()
        self.name = name
        self.type = type
        self.host = host
        self.port = port
        self.username = username
        self.password = nil  // 不再存储密码到 SwiftData
        self.databaseName = databaseName
        self.filePath = filePath
        self.createdAt = Date()
        self.updatedAt = Date()
        
        // 如果提供了密码，存储到 Keychain
        if let pwd = password, !pwd.isEmpty {
            try? KeychainService.shared.savePassword(pwd, for: self.id)
        }
    }
    
    // MARK: - Keychain 密码管理
    
    /// 从 Keychain 获取密码
    /// - Returns: 密码字符串，如果不存在则返回 nil
    func getSecurePassword() -> String? {
        // 首先尝试从 Keychain 获取
        if let keychainPassword = KeychainService.shared.getPassword(for: id) {
            return keychainPassword
        }
        
        // 如果 Keychain 中没有，检查是否有旧的明文密码需要迁移
        if let legacyPassword = password, !legacyPassword.isEmpty {
            migratePasswordToKeychain()
            return legacyPassword
        }
        
        return nil
    }
    
    /// 设置密码（存储到 Keychain）
    /// - Parameter newPassword: 新密码
    func setSecurePassword(_ newPassword: String?) {
        if let pwd = newPassword, !pwd.isEmpty {
            try? KeychainService.shared.savePassword(pwd, for: id)
        } else {
            KeychainService.shared.deletePassword(for: id)
        }
        // 确保 SwiftData 中不存储密码
        self.password = nil
    }
    
    /// 将旧的明文密码迁移到 Keychain
    /// 迁移后清空 SwiftData 中的密码字段
    func migratePasswordToKeychain() {
        guard let legacyPassword = password, !legacyPassword.isEmpty else { return }
        
        // 检查 Keychain 中是否已有密码
        if KeychainService.shared.hasPassword(for: id) {
            // Keychain 中已有密码，直接清空 SwiftData
            self.password = nil
            print("[Migration] 连接 \(name): Keychain 已有密码，清空 SwiftData")
            return
        }
        
        // 迁移到 Keychain
        do {
            try KeychainService.shared.savePassword(legacyPassword, for: id)
            self.password = nil
            print("[Migration] 连接 \(name): 密码已迁移到 Keychain")
        } catch {
            print("[Migration] 连接 \(name): 迁移失败 - \(error)")
        }
    }
    
    /// 删除 Keychain 中的密码
    func deleteSecurePassword() {
        KeychainService.shared.deletePassword(for: id)
    }
}

enum DatabaseType: String, Codable, CaseIterable, Identifiable {
    case sqlite = "SQLite"
    case mysql = "MySQL"
    case postgresql = "PostgreSQL"
    
    var id: String { self.rawValue }
}
