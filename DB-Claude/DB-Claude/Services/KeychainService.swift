import Foundation
import Security

/// Keychain 错误类型
enum KeychainError: Error, LocalizedError {
    case duplicateEntry
    case unknown(OSStatus)
    case itemNotFound
    case encodingFailed
    
    var errorDescription: String? {
        switch self {
        case .duplicateEntry:
            return "Keychain 中已存在该条目"
        case .unknown(let status):
            return "Keychain 操作失败: \(status)"
        case .itemNotFound:
            return "Keychain 中未找到该条目"
        case .encodingFailed:
            return "密码编码失败"
        }
    }
}

/// Keychain 服务 - 安全存储数据库连接密码
/// 
/// 使用 macOS Keychain 安全存储敏感凭据，避免明文存储密码。
/// 密码以 Connection ID 为 key 进行存储和检索。
/// 
/// 使用 Keychain 访问组确保开发阶段签名变化时仍可访问密码。
final class KeychainService: @unchecked Sendable {
    static let shared = KeychainService()
    
    /// Keychain 服务标识符
    private let service = "com.db-claude.connections"
    
    /// Keychain 访问组（与 entitlements 中的配置一致）
    /// 使用访问组可以避免开发阶段因签名变化导致的弹窗确认
    private var accessGroup: String? {
        // 获取 Team ID 前缀
        if let teamId = Bundle.main.infoDictionary?["AppIdentifierPrefix"] as? String {
            return "\(teamId)yichen.DB-Claude"
        }
        // 开发阶段可能没有 Team ID，返回 nil 使用默认行为
        return nil
    }
    
    private init() {}
    
    // MARK: - Public API
    
    /// 保存密码到 Keychain
    /// - Parameters:
    ///   - password: 要保存的密码
    ///   - connectionId: 连接 ID
    /// - Throws: KeychainError
    func savePassword(_ password: String, for connectionId: UUID) throws {
        let account = connectionId.uuidString
        
        guard let data = password.data(using: .utf8) else {
            throw KeychainError.encodingFailed
        }
        
        // 构建查询字典
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            // 用户登录后即可访问，无需额外确认
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]
        
        // 如果有访问组，添加到查询中
        if let group = accessGroup {
            query[kSecAttrAccessGroup as String] = group
        }
        
        // 先尝试删除已存在的条目（更新场景）
        deletePassword(for: connectionId)
        
        // 添加新条目
        let status = SecItemAdd(query as CFDictionary, nil)
        
        guard status == errSecSuccess else {
            if status == errSecDuplicateItem {
                throw KeychainError.duplicateEntry
            }
            throw KeychainError.unknown(status)
        }
        
        print("[Keychain] 密码已保存: \(account)")
    }
    
    /// 从 Keychain 读取密码
    /// - Parameter connectionId: 连接 ID
    /// - Returns: 密码字符串，如果不存在则返回 nil
    func getPassword(for connectionId: UUID) -> String? {
        let account = connectionId.uuidString
        
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
            // 禁用用户交互提示（避免弹窗要求输入系统密码）
            // 如果无法静默访问，返回错误而非弹窗
            kSecUseAuthenticationUI as String: kSecUseAuthenticationUISkip
        ]
        
        // 如果有访问组，添加到查询中
        if let group = accessGroup {
            query[kSecAttrAccessGroup as String] = group
        }
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let password = String(data: data, encoding: .utf8) else {
            if status == errSecInteractionNotAllowed {
                // 需要用户交互但被禁用，密码存在但无法静默访问
                print("[Keychain] 密码存在但需要用户确认，跳过: \(account)")
            } else if status != errSecItemNotFound {
                print("[Keychain] 读取密码失败: \(status)")
            }
            return nil
        }
        
        return password
    }
    
    /// 从 Keychain 删除密码
    /// - Parameter connectionId: 连接 ID
    @discardableResult
    func deletePassword(for connectionId: UUID) -> Bool {
        let account = connectionId.uuidString
        
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        
        // 如果有访问组，添加到查询中
        if let group = accessGroup {
            query[kSecAttrAccessGroup as String] = group
        }
        
        let status = SecItemDelete(query as CFDictionary)
        
        if status == errSecSuccess {
            print("[Keychain] 密码已删除: \(account)")
            return true
        } else if status == errSecItemNotFound {
            // 条目不存在，视为成功
            return true
        } else {
            print("[Keychain] 删除密码失败: \(status)")
            return false
        }
    }
    
    /// 检查 Keychain 中是否存在密码
    /// - Parameter connectionId: 连接 ID
    /// - Returns: 是否存在
    func hasPassword(for connectionId: UUID) -> Bool {
        return getPassword(for: connectionId) != nil
    }
    
    /// 更新 Keychain 中的密码
    /// - Parameters:
    ///   - password: 新密码
    ///   - connectionId: 连接 ID
    /// - Throws: KeychainError
    func updatePassword(_ password: String, for connectionId: UUID) throws {
        // 直接调用 save，save 内部会先删除再添加
        try savePassword(password, for: connectionId)
    }
}
