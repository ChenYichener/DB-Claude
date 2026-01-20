<p align="center">
  <img src="docs/assets/logo.png" alt="DB-Claude Logo" width="128" height="128">
</p>

<h1 align="center">DB-Claude</h1>

<p align="center">
  <strong>A native macOS database management tool built with Swift and SwiftUI</strong>
</p>

<p align="center">
  <a href="./README.md">English</a> | <a href="./README_CN.md">简体中文</a>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/platform-macOS%2015.7+-blue.svg" alt="Platform">
  <img src="https://img.shields.io/badge/swift-5.0-orange.svg" alt="Swift">
  <img src="https://img.shields.io/badge/license-MIT-green.svg" alt="License">
  <img src="https://img.shields.io/badge/dependencies-zero-brightgreen.svg" alt="Dependencies">
</p>

---

## Features

### 🎯 Smart SQL Editor

- **Chinese Punctuation Auto-Convert** - Automatically converts Chinese punctuation (，。；：""'' etc.) to English equivalents, preventing SQL syntax errors
- **Syntax Highlighting** - Color-coded keywords, functions, strings, numbers, and comments for better readability
- **Intelligent Auto-Complete** - Auto-suggests SQL keywords, built-in functions, table names, and column names
- **Auto-Uppercase Keywords** - Typing `select` automatically becomes `SELECT` for consistent code style
- **SQL Formatting** - One-click beautification with proper line breaks and indentation
- **Real-time Validation** - Instant syntax error detection with fix suggestions
- **Execute Selection** - Run selected SQL portions independently for easier debugging
- **EXPLAIN Query** - One-click execution plan analysis for query optimization
- **Adjustable Font Size** - Customize editor font size to your preference
- **Context Menu** - Quick actions: execute, format, copy as escaped string

### 📊 Table Data Browser

- **Pagination** - Support for 20/50/100/200 rows per page, smooth browsing for large tables
- **Click-to-Sort** - Click column headers to sort (ascending/descending)
- **Filter Conditions** - Multiple operators: equals, not equals, greater than, less than, LIKE, IS NULL, etc.
- **Visual Editing** - Edit cell content directly, preview generated SQL before execution

### 🗄️ Multi-Database Support

| Database | Status |
|----------|--------|
| SQLite | ✅ Full Support |
| MySQL | 🚧 In Development |
| PostgreSQL | 📋 Planned |

### 💻 Native Experience

- **Zero Dependencies** - Pure system frameworks, small footprint, high performance
- **Modern UI** - SwiftUI-based three-column layout following macOS design guidelines
- **Multi-Tab** - Open multiple query and table structure tabs simultaneously
- **Query History** - Automatic SQL statement logging for easy recall

## Keyboard Shortcuts

| Action | Shortcut |
|--------|----------|
| Execute SQL | `⌘ + Enter` |
| Format SQL | `⌘ + Shift + F` |
| Auto-Complete | `Tab` |
| Cancel Completion | `Esc` |

## Tech Stack

| Component | Technology |
|-----------|------------|
| Language | Swift 5.0 |
| UI Framework | SwiftUI |
| Data Persistence | SwiftData |
| Minimum Target | macOS 15.7 |

## Screenshots

*Coming soon*

## Getting Started

### Requirements

- macOS 15.7+
- Xcode 16.0+

### Build

```bash
# Command line build
xcodebuild -project DB-Claude.xcodeproj -scheme DB-Claude -configuration Debug build

# Or open in Xcode
open DB-Claude.xcodeproj
```

## Architecture

The project follows MVVM layered architecture:

```
┌─────────────────────────────────────────────────────────────┐
│                    Views (SwiftUI)                          │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐       │
│  │ Sidebar  │ │  Query   │ │ Results  │ │ History  │       │
│  │  View    │ │  Editor  │ │   Grid   │ │Inspector │       │
│  └──────────┘ └──────────┘ └──────────┘ └──────────┘       │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│              ViewModels (@Observable)                        │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  TabManager: Manages workspace tabs and selection     │   │
│  └──────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│                    Models (@Model)                           │
│  ┌──────────────────────┐ ┌──────────────────────────┐      │
│  │     Connection       │ │      QueryHistory        │      │
│  │  SwiftData Persisted │ │   sql, timestamp, etc.   │      │
│  └──────────────────────┘ └──────────────────────────┘      │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│                   Drivers (Protocol)                         │
│  ┌──────────────────────┐ ┌──────────────────────────┐      │
│  │    SQLiteDriver      │ │      MySQLDriver         │      │
│  │   SQLite3 C API      │ │    In Development        │      │
│  └──────────────────────┘ └──────────────────────────┘      │
└─────────────────────────────────────────────────────────────┘
```

For detailed architecture documentation, see [CLAUDE.md](./CLAUDE.md).

## Roadmap

- [x] Phase 1: UI skeleton, connection management, SQLite driver
- [x] Phase 2: Multi-tab, SQL editor, results grid
- [x] Phase 3: Query history, keyboard shortcuts
- [ ] Phase 4: AI agent integration, NL2SQL

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
