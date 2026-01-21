//
//  DB_ClaudeApp.swift
//  DB-Claude
//
//  Created by 陈一臣的Mac on 2026/1/19.
//

import SwiftUI
import SwiftData

@main
struct DB_ClaudeApp: App {
    @Environment(\.openWindow) private var openWindow
    @FocusedBinding(\.showAddConnection) private var showAddConnection
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Connection.self,
            QueryHistory.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
        .commands {
            // "连接" 菜单
            CommandMenu("连接") {
                Button("新增连接...") {
                    showAddConnection = true
                }
                .keyboardShortcut("N", modifiers: [.command, .shift])
            }
            
            CommandGroup(after: .windowSize) {
                Divider()
                Button("SQL 执行日志") {
                    openWindow(id: "sql-log")
                }
                .keyboardShortcut("L", modifiers: [.command, .shift])
            }
        }
        
        // SQL 日志窗口
        Window("SQL 执行日志", id: "sql-log") {
            SQLLogWindow()
        }
        .defaultSize(width: 900, height: 600)
    }
}
