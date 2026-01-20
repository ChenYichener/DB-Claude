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
