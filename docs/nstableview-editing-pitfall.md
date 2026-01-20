# NSTableView 单元格编辑功能开发陷阱

本文档记录了在 SwiftUI 的 `NSViewRepresentable` 中实现 NSTableView 单元格编辑功能时遇到的问题及解决方案。

## 背景

在 `TableDataView` 中使用 `EditableResultsGridView`（基于 `NSViewRepresentable`）实现数据表格的编辑功能。用户可以切换"编辑模式"，然后双击单元格进行编辑。

## 问题一：NSTextField 编辑事件捕获不完整

### 现象
用户编辑单元格后点击其他地方，编辑内容丢失。只有按 Enter 键才能保存。

### 原因
最初使用 `target/action` 机制处理编辑事件：

```swift
textField.target = self
textField.action = #selector(textFieldDidEndEditing(_:))
```

**问题**：`action` 只在用户按 **Enter** 键时触发。如果用户点击其他单元格或其他地方失去焦点，`action` 不会被调用。

### 解决方案
让 Coordinator 实现 `NSTextFieldDelegate` 协议，使用 `controlTextDidEndEditing(_:)` 方法捕获所有编辑结束事件：

```swift
class Coordinator: NSObject, NSTableViewDelegate, NSTableViewDataSource, NSTextFieldDelegate {
    // 编辑结束时的回调（失去焦点时触发）
    func controlTextDidEndEditing(_ obj: Notification) {
        guard let textField = obj.object as? NSTextField else { return }
        processEditEnd(textField: textField)
    }
}

// 在创建 NSTextField 时设置 delegate
textField.delegate = self  // self 是 Coordinator
```

### 关键点
- `NSTextFieldDelegate` 的 `controlTextDidEndEditing(_:)` 在**任何编辑结束时**都会触发（包括失去焦点）
- `target/action` 只在**按 Enter 键**时触发
- 两者可以同时使用，但 `delegate` 方法更可靠

---

## 问题二：编辑时 reloadData 导致编辑中断

### 现象
用户刚开始编辑，编辑状态立即结束，无法输入内容。

### 原因
在 `updateNSView` 中，当数据变化时会调用 `reloadData()`：

```swift
func updateNSView(_ scrollView: NSScrollView, context: Context) {
    if needsReload {
        tableView.reloadData()  // 这会销毁当前编辑的单元格！
    }
}
```

当用户开始编辑时，SwiftUI 可能因为某些状态变化触发 `updateNSView`，如果此时调用 `reloadData()`，当前编辑的单元格会被销毁重建，导致编辑中断。

### 解决方案
在 `reloadData()` 之前检查是否正在编辑：

```swift
func updateNSView(_ scrollView: NSScrollView, context: Context) {
    // 检查是否正在编辑
    let firstResponder = tableView.window?.firstResponder
    let isCurrentlyEditing = firstResponder is NSTextView || 
                             (firstResponder is NSTextField && tableView.isEditingEnabled)
    
    // 如果正在编辑，跳过 reloadData
    if needsReload && !isCurrentlyEditing {
        tableView.reloadData()
    }
}
```

### 关键点
- NSTextField 编辑时，实际的文本编辑由 **field editor**（一个 NSTextView）处理
- 检查 `window?.firstResponder` 是否为 `NSTextView` 或 `NSTextField` 来判断是否正在编辑
- 编辑期间不要调用 `reloadData()`

---

## 问题三：单元格 isEditable 属性不同步（最关键的问题）

### 现象
切换到编辑模式后，点击单元格仍然无法编辑。日志显示 `isEditable=false`。

### 原因
NSTableView 会复用单元格（类似 UITableView 的 cell reuse）。单元格在**编辑模式切换之前**就已经创建好了：

```
[EditableGrid] 配置单元格: row=3, col=tenant_id, isEditable=false  ← 创建时 isEditable=false
[TableDataView] 编辑模式切换: isEditMode=true  ← 之后才切换
[EditableGrid] updateNSView: needsReload=false  ← 没有 reload，现有单元格不会更新！
```

当 `updateNSView` 被调用时，`needsReload=false`（因为数据没变），所以 `reloadData()` 不会被调用，**现有单元格的 `isEditable` 属性保持为 `false`**。

### 解决方案
在 `updateNSView` 中检测编辑模式变化，手动更新所有可见单元格的 `isEditable` 属性：

```swift
func updateNSView(_ scrollView: NSScrollView, context: Context) {
    let editModeChanged = coordinator.isEditable != isEditable
    
    // 更新 coordinator 的状态
    coordinator.isEditable = isEditable
    tableView.isEditingEnabled = isEditable
    
    // 关键：当编辑模式变化时，更新所有可见单元格
    if editModeChanged {
        updateAllVisibleCellsEditability(tableView: tableView, isEditable: isEditable)
    }
}

// 更新所有可见单元格的编辑状态
private func updateAllVisibleCellsEditability(tableView: NSTableView, isEditable: Bool) {
    let visibleRows = tableView.rows(in: tableView.visibleRect)
    
    for row in visibleRows.location..<(visibleRows.location + visibleRows.length) {
        for col in 0..<tableView.numberOfColumns {
            if let cellView = tableView.view(atColumn: col, row: row, makeIfNecessary: false) as? NSTableCellView,
               let textField = cellView.textField {
                textField.isEditable = isEditable
            }
        }
    }
}
```

### 关键点
- NSTableView 的单元格是**复用**的，状态可能与当前期望不一致
- `updateNSView` 被调用时，不一定会触发 `reloadData()`
- 当关键属性（如 `isEditable`）变化时，需要**手动遍历更新**所有可见单元格
- 使用 `rows(in: visibleRect)` 获取可见行范围，只更新可见的单元格

---

## 调试技巧

### 1. 添加详细日志
在关键位置添加日志，追踪状态变化：

```swift
print("[EditableGrid] 配置单元格: row=\(row), col=\(columnName), isEditable=\(isEditable)")
print("[EditableGrid] updateNSView: needsReload=\(needsReload), editModeChanged=\(editModeChanged)")
print("[EditableGrid] >>> 编辑开始/结束")
```

### 2. 检查事件流
确认以下事件是否按预期触发：
- `mouseDown` - 鼠标点击
- `validateProposedFirstResponder` - 焦点验证
- `controlTextDidBeginEditing` - 编辑开始
- `controlTextDidEndEditing` - 编辑结束

### 3. 检查关键属性
- `textField.isEditable` - 是否可编辑
- `textField.isSelectable` - 是否可选择
- `textField.acceptsFirstResponder` - 是否接受焦点
- `window?.firstResponder` - 当前焦点所在

---

## 总结

在 SwiftUI 的 `NSViewRepresentable` 中使用 NSTableView 实现编辑功能时，需要注意：

1. **事件捕获**：使用 `NSTextFieldDelegate` 而非仅依赖 `target/action`
2. **视图更新**：编辑期间避免 `reloadData()`
3. **状态同步**：属性变化时手动更新所有可见单元格

这三个问题相互关联，任何一个都可能导致"无法编辑"的现象。调试时需要通过日志逐步排查，确定具体是哪个环节出了问题。
