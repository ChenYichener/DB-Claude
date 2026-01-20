import Foundation
import SwiftData

@Model
final class QueryHistory {
    var id: UUID
    var sql: String
    var timestamp: Date
    var executionTime: TimeInterval
    var status: String // "Success" or "Error"
    var connectionID: UUID
    var databaseName: String?
    
    init(sql: String, executionTime: TimeInterval, status: String, connectionID: UUID, databaseName: String? = nil) {
        self.id = UUID()
        self.sql = sql
        self.timestamp = Date()
        self.executionTime = executionTime
        self.status = status
        self.connectionID = connectionID
        self.databaseName = databaseName
    }
}
