import SwiftUI
import Combine

enum TabType: Equatable {
    case query
    case structure(String) // 显示 DDL
    case data(String)      // 显示表数据
    
    var isQuery: Bool {
        if case .query = self { return true }
        return false
    }
    
    var isData: Bool {
        if case .data = self { return true }
        return false
    }
}

struct WorkspaceTab: Identifiable, Equatable {
    let id: UUID
    var title: String
    var type: TabType
    var connectionId: UUID // Tab belongs to a connection context? Or Global? usually connection context.
    var isRenamable: Bool { type.isQuery }  // 只有查询 tab 可以重命名
}

@Observable
class TabManager {
    var tabs: [WorkspaceTab] = []
    var activeTabId: UUID?
    
    // 按类型分组的 tabs
    var dataTabs: [WorkspaceTab] {
        tabs.filter { $0.type.isData || !$0.type.isQuery }
    }
    
    var queryTabs: [WorkspaceTab] {
        tabs.filter { $0.type.isQuery }
    }
    
    // Helper to generate default title
    private func defaultTitle(for type: TabType, count: Int) -> String {
        switch type {
        case .query: return "Query \(count)"
        case .structure(let table): return table
        case .data(let table): return "\(table) (数据)"
        }
    }
    
    func addQueryTab(connectionId: UUID) {
        let count = tabs.filter { if case .query = $0.type { return true } else { return false } }.count + 1
        let tab = WorkspaceTab(
            id: UUID(),
            title: "Query \(count)",
            type: .query,
            connectionId: connectionId
        )
        tabs.append(tab)
        activeTabId = tab.id
    }
    
    func openStructureTab(table: String, connectionId: UUID) {
        // Check if exists
        if let existing = tabs.first(where: {
            if case .structure(let t) = $0.type, t == table, $0.connectionId == connectionId { return true }
            return false
        }) {
            activeTabId = existing.id
            return
        }

        let tab = WorkspaceTab(
            id: UUID(),
            title: table,
            type: .structure(table),
            connectionId: connectionId
        )
        tabs.append(tab)
        activeTabId = tab.id
    }

    func openDataTab(table: String, connectionId: UUID) {
        print("[TabManager] openDataTab 被调用: table=\(table), connectionId=\(connectionId)")

        // 检查是否已存在，如果存在则激活
        if let existing = tabs.first(where: {
            if case .data(let t) = $0.type, t == table, $0.connectionId == connectionId { return true }
            return false
        }) {
            print("[TabManager] 找到已存在的 tab，激活它: \(existing.id)")
            activeTabId = existing.id
            return
        }

        print("[TabManager] 创建新 data tab")
        let tab = WorkspaceTab(
            id: UUID(),
            title: "\(table) (数据)",
            type: .data(table),
            connectionId: connectionId
        )
        tabs.append(tab)
        activeTabId = tab.id
        print("[TabManager] 新 tab 已创建，总数: \(tabs.count)")
    }

    func closeTab(id: UUID) {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }
        let wasActive = activeTabId == id
        tabs.remove(at: index)
        
        if wasActive {
            if tabs.isEmpty {
                activeTabId = nil
            } else {
                // Select previous or next
                let newIndex = min(index, tabs.count - 1)
                activeTabId = tabs[newIndex].id
            }
        }
    }
    
    /// 重命名 tab（仅支持查询 tab）
    func renameTab(id: UUID, newTitle: String) {
        guard let index = tabs.firstIndex(where: { $0.id == id }),
              tabs[index].isRenamable else { return }
        tabs[index].title = newTitle
    }
}
