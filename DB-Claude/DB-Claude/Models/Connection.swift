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
    var password: String?
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
        self.password = password
        self.databaseName = databaseName
        self.filePath = filePath
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

enum DatabaseType: String, Codable, CaseIterable, Identifiable {
    case sqlite = "SQLite"
    case mysql = "MySQL"
    case postgresql = "PostgreSQL"
    
    var id: String { self.rawValue }
}
