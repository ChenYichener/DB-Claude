# NSTableView 数据显示问题排查指南

本文档总结了在 SwiftUI 中使用 NSViewRepresentable 包装 NSTableView 时，可能遇到的数据不显示问题及其解决方案。

## 问题背景

在 `EditableResultsGridView` 组件中，频繁出现执行 SQL 后表格不显示数据行的问题。经过多次调试，发现了以下几类常见问题。

---

## 问题 1：columnIndexMap 未同步更新

### 症状
- 表格有列头，但没有数据行
- 控制台无明显错误

### 原因
在 `updateNSView` 中更新 `coordinator.columns` 和 `coordinator.rowData` 后，忘记同步更新 `columnIndexMap`。

```swift
// ❌ 错误：只更新了 columns 和 rowData
coordinator.columns = columns
coordinator.rowData = rowData
// columnIndexMap 仍然是旧的映射！
```

### 解决方案
在更新数据后，必须同步更新 `columnIndexMap`：

```swift
// ✅ 正确：同步更新 columnIndexMap
coordinator.columns = columns
coordinator.rowData = rowData

coordinator.columnIndexMap.removeAll()
for (index, col) in columns.enumerated() {
    coordinator.columnIndexMap[col] = index
}
```

---

## 问题 2：dataHash 计算过于简单

### 症状
- 第一次查询显示正常
- 执行不同的查询（但返回行数相同）时，数据不更新

### 原因
原来的 `dataHash` 只使用 `rowData.count`（行数），导致：
- 查询 A 返回 100 行，hash = 100
- 查询 B 也返回 100 行，hash = 100
- `needsReload = (100 != 100) = false`，不触发刷新

```swift
// ❌ 错误：只用行数作为 hash
self.dataHash = dataRows.count
```

### 解决方案
使用基于数据内容的 hash：

```swift
// ✅ 正确：基于数据内容计算 hash
private static func computeDataHash(rowData: [[String?]]) -> Int {
    var hasher = Hasher()
    hasher.combine(rowData.count)
    // 采样前 10 行和后 10 行，避免大数据集性能问题
    let sampleRows = Array(rowData.prefix(10)) + Array(rowData.suffix(10))
    for row in sampleRows {
        for value in row {
            hasher.combine(value)
        }
    }
    return hasher.finalize()
}
```

---

## 问题 3：isCurrentlyEditing 误判

### 症状
- 控制台显示 `跳过 reloadData（正在编辑中）`
- 但用户并没有在表格中编辑

### 原因
原来的判断逻辑检测整个窗口的 `firstResponder`：

```swift
// ❌ 错误：检测整个窗口的 firstResponder
let firstResponder = tableView.window?.firstResponder
let isCurrentlyEditing = firstResponder is NSTextView || 
                         (firstResponder is NSTextField && tableView.isEditingEnabled)
```

当用户在 SQL 编辑器中输入并执行查询时，SQL 编辑器的 NSTextView 是 firstResponder，被误判为表格正在编辑。

### 解决方案
只检测表格内部的编辑状态：

```swift
// ✅ 正确：只检测表格内部的编辑状态
let isCurrentlyEditing: Bool = {
    guard let firstResponder = tableView.window?.firstResponder else { return false }
    // 检查 firstResponder 是否是表格内部的 field editor 或 text field
    if let textView = firstResponder as? NSTextView,
       let delegate = textView.delegate as? NSTextField,
       delegate.superview?.superview === tableView {
        return true
    }
    if let textField = firstResponder as? NSTextField,
       textField.superview?.superview === tableView {
        return true
    }
    return false
}()
```

---

## 问题 4：makeNSView 未调用 reloadData

### 症状
- 视图首次创建时不显示数据
- 但切换标签页后再回来就能显示

### 原因
`makeNSView` 创建表格后，没有调用 `reloadData()` 进行初始数据加载。

### 解决方案
在 `makeNSView` 末尾添加 `reloadData()` 调用：

```swift
func makeNSView(context: Context) -> NSScrollView {
    // ... 创建和配置表格 ...
    
    scrollView.documentView = tableView
    
    // ✅ 初始加载数据
    tableView.reloadData()
    
    return scrollView
}
```

---

## 调试技巧

### 1. 添加关键日志点

```swift
// 在 init 中记录数据解析结果
print("[ResultsGrid] init: columns=\(cols.count), dataRows=\(dataRows.count), hash=\(self.dataHash)")

// 在 updateNSView 中记录刷新决策
print("[EditableGrid] updateNSView: needsReload=\(needsReload), hash=\(dataHash), oldHash=\(coordinator.dataHash)")

// 在 QueryEditorView 中记录查询结果
print("[QueryEditor] 查询完成, rows=\(rows.count)")
```

### 2. 检查日志顺序

正确的日志顺序应该是：
1. `[QueryEditor] 查询完成, rows=X`
2. `[ResultsGrid] init: ...`
3. `[EditableGrid] updateNSView: needsReload=true`
4. `[EditableGrid] updateNSView: 执行 reloadData`

如果看到 `跳过 reloadData`，说明刷新被阻止了，需要检查原因。

### 3. 常见问题检查清单

- [ ] `columnIndexMap` 是否在数据更新时同步更新？
- [ ] `dataHash` 是否能正确区分不同的数据？
- [ ] `isCurrentlyEditing` 判断是否只针对表格内部？
- [ ] `makeNSView` 是否调用了 `reloadData()`？
- [ ] `needsReload` 判断条件是否正确？

---

## 相关文件

- `DB-Claude/DB-Claude/Views/ResultsGridView.swift` - 主要的表格视图实现
- `DB-Claude/DB-Claude/Views/QueryEditorView.swift` - SQL 编辑器和结果显示
- `docs/nstableview-editing-pitfall.md` - NSTableView 编辑相关的陷阱
