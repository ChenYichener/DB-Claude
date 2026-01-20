import AppKit
import SwiftUI

/// 自动补全弹出窗口
class CompletionWindow: NSPanel {
    private var tableView: NSTableView!
    private var scrollView: NSScrollView!
    private var items: [CompletionItem] = []
    private var selectedIndex: Int = 0
    
    weak var completionDelegate: CompletionDelegate?
    
    var selectedItem: CompletionItem? {
        guard selectedIndex >= 0 && selectedIndex < items.count else { return nil }
        return items[selectedIndex]
    }
    
    override init(contentRect: NSRect, styleMask style: NSWindow.StyleMask, backing backingStoreType: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(contentRect: contentRect, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        
        self.isFloatingPanel = true
        self.level = .popUpMenu
        self.hasShadow = true
        self.isOpaque = false
        self.backgroundColor = .clear
        
        setupUI()
    }
    
    convenience init() {
        self.init(contentRect: NSRect(x: 0, y: 0, width: 300, height: 200),
                  styleMask: .borderless,
                  backing: .buffered,
                  defer: true)
    }
    
    private func setupUI() {
        // 创建容器视图
        let containerView = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: 300, height: 200))
        containerView.material = .popover
        containerView.state = .active
        containerView.wantsLayer = true
        containerView.layer?.cornerRadius = 8
        containerView.layer?.masksToBounds = true
        containerView.layer?.borderWidth = 1
        containerView.layer?.borderColor = NSColor.separatorColor.cgColor
        
        // 创建表格视图
        tableView = NSTableView()
        tableView.style = .plain
        tableView.selectionHighlightStyle = .regular
        tableView.backgroundColor = .clear
        tableView.headerView = nil
        tableView.intercellSpacing = NSSize(width: 0, height: 2)
        tableView.rowHeight = 24
        tableView.target = self
        tableView.doubleAction = #selector(handleDoubleClick)
        
        // 添加列
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("completion"))
        column.width = 280
        tableView.addTableColumn(column)
        
        tableView.delegate = self
        tableView.dataSource = self
        
        // 创建滚动视图
        scrollView = NSScrollView()
        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        
        containerView.addSubview(scrollView)
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 4),
            scrollView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 4),
            scrollView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -4),
            scrollView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -4)
        ])
        
        self.contentView = containerView
    }
    
    func updateItems(_ newItems: [CompletionItem]) {
        items = newItems
        selectedIndex = 0
        tableView.reloadData()
        
        if !items.isEmpty {
            tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        }
        
        // 调整窗口大小
        let height = min(CGFloat(items.count) * 26 + 12, 250)
        let newFrame = NSRect(x: frame.origin.x, y: frame.origin.y, width: 320, height: height)
        setFrame(newFrame, display: true)
    }
    
    func showAt(point: NSPoint, relativeTo parentWindow: NSWindow) {
        // 计算屏幕上的位置
        var windowPoint = point
        
        // 确保窗口在屏幕内
        if let screen = parentWindow.screen {
            let screenFrame = screen.visibleFrame
            
            // 调整水平位置
            if windowPoint.x + frame.width > screenFrame.maxX {
                windowPoint.x = screenFrame.maxX - frame.width - 10
            }
            
            // 调整垂直位置 - 如果下方空间不足，显示在上方
            if windowPoint.y - frame.height < screenFrame.minY {
                windowPoint.y = point.y + 20  // 显示在光标上方
            } else {
                windowPoint.y = point.y - frame.height
            }
        }
        
        setFrameOrigin(windowPoint)
        parentWindow.addChildWindow(self, ordered: .above)
        orderFront(nil)
    }
    
    func hide() {
        parent?.removeChildWindow(self)
        orderOut(nil)
    }
    
    func selectNext() {
        guard !items.isEmpty else { return }
        selectedIndex = min(selectedIndex + 1, items.count - 1)
        tableView.selectRowIndexes(IndexSet(integer: selectedIndex), byExtendingSelection: false)
        tableView.scrollRowToVisible(selectedIndex)
    }
    
    func selectPrevious() {
        guard !items.isEmpty else { return }
        selectedIndex = max(selectedIndex - 1, 0)
        tableView.selectRowIndexes(IndexSet(integer: selectedIndex), byExtendingSelection: false)
        tableView.scrollRowToVisible(selectedIndex)
    }
    
    @objc private func handleDoubleClick() {
        guard let item = selectedItem else { return }
        completionDelegate?.didSelectItem(item)
    }
}

// MARK: - NSTableViewDelegate & DataSource
extension CompletionWindow: NSTableViewDelegate, NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return items.count
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row < items.count else { return nil }
        let item = items[row]
        
        let cellView = NSView()
        cellView.wantsLayer = true
        
        // 类型图标
        let iconLabel = NSTextField(labelWithString: item.type.icon)
        iconLabel.font = NSFont.systemFont(ofSize: 11, weight: .bold)
        iconLabel.textColor = item.type.color
        iconLabel.alignment = .center
        iconLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let iconBg = NSView()
        iconBg.wantsLayer = true
        iconBg.layer?.backgroundColor = item.type.color.withAlphaComponent(0.15).cgColor
        iconBg.layer?.cornerRadius = 3
        iconBg.translatesAutoresizingMaskIntoConstraints = false
        iconBg.addSubview(iconLabel)
        
        cellView.addSubview(iconBg)
        
        // 补全文本
        let textLabel = NSTextField(labelWithString: item.text)
        textLabel.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        textLabel.textColor = .textColor
        textLabel.lineBreakMode = .byTruncatingTail
        textLabel.translatesAutoresizingMaskIntoConstraints = false
        cellView.addSubview(textLabel)
        
        // 详情（如表名）
        var detailLabel: NSTextField?
        if let detail = item.detail {
            let label = NSTextField(labelWithString: detail)
            label.font = NSFont.systemFont(ofSize: 10)
            label.textColor = .secondaryLabelColor
            label.translatesAutoresizingMaskIntoConstraints = false
            cellView.addSubview(label)
            detailLabel = label
        }
        
        NSLayoutConstraint.activate([
            // 图标背景
            iconBg.leadingAnchor.constraint(equalTo: cellView.leadingAnchor, constant: 4),
            iconBg.centerYAnchor.constraint(equalTo: cellView.centerYAnchor),
            iconBg.widthAnchor.constraint(equalToConstant: 18),
            iconBg.heightAnchor.constraint(equalToConstant: 18),
            
            // 图标
            iconLabel.centerXAnchor.constraint(equalTo: iconBg.centerXAnchor),
            iconLabel.centerYAnchor.constraint(equalTo: iconBg.centerYAnchor),
            
            // 文本
            textLabel.leadingAnchor.constraint(equalTo: iconBg.trailingAnchor, constant: 8),
            textLabel.centerYAnchor.constraint(equalTo: cellView.centerYAnchor)
        ])
        
        if let detail = detailLabel {
            NSLayoutConstraint.activate([
                textLabel.trailingAnchor.constraint(lessThanOrEqualTo: detail.leadingAnchor, constant: -8),
                detail.trailingAnchor.constraint(equalTo: cellView.trailingAnchor, constant: -8),
                detail.centerYAnchor.constraint(equalTo: cellView.centerYAnchor)
            ])
        } else {
            textLabel.trailingAnchor.constraint(lessThanOrEqualTo: cellView.trailingAnchor, constant: -8).isActive = true
        }
        
        return cellView
    }
    
    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        return 24
    }
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        selectedIndex = tableView.selectedRow
    }
}

// MARK: - 补全项行视图
class CompletionRowView: NSTableRowView {
    override func drawSelection(in dirtyRect: NSRect) {
        if selectionHighlightStyle != .none {
            let selectionRect = bounds.insetBy(dx: 2, dy: 1)
            NSColor.selectedContentBackgroundColor.withAlphaComponent(0.3).setFill()
            let path = NSBezierPath(roundedRect: selectionRect, xRadius: 4, yRadius: 4)
            path.fill()
        }
    }
}

extension CompletionWindow {
    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        return CompletionRowView()
    }
}
