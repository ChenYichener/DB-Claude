import SwiftUI
import AppKit

// MARK: - Color 扩展

extension Color {
    /// 从 hex 字符串创建颜色
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
    
    /// 支持 light/dark 模式的颜色
    init(light: Color, dark: Color) {
        self.init(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
            if appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua {
                return NSColor(dark)
            } else {
                return NSColor(light)
            }
        }))
    }
}

// MARK: - 设计系统 - 颜色

/// 统一的颜色体系 - 现代简洁风格
enum AppColors {
    // === 背景层级（更白更干净）===
    static let background = Color(light: .white, dark: Color(hex: "1C1C1E"))
    static let secondaryBackground = Color(light: Color(hex: "F5F5F7"), dark: Color(hex: "2C2C2E"))
    static let tertiaryBackground = Color(light: Color(hex: "EBEBF0"), dark: Color(hex: "3A3A3C"))
    
    // === 文字层级 ===
    static let primaryText = Color(light: Color(hex: "1D1D1F"), dark: .white)
    static let secondaryText = Color(light: Color(hex: "6E6E73"), dark: Color(hex: "8E8E93"))
    static let tertiaryText = Color(light: Color(hex: "AEAEB2"), dark: Color(hex: "636366"))
    
    // === 品牌色 ===
    static let accent = Color.accentColor
    static let accentSubtle = Color.accentColor.opacity(0.12)
    static let accentMuted = Color.accentColor.opacity(0.2)
    
    // === 状态色 ===
    static let success = Color(hex: "34C759")
    static let error = Color(hex: "FF3B30")
    static let warning = Color(hex: "FF9500")

    // === SQL 语法高亮色 ===
    static let sqlKeyword = Color(hex: "FF79C6")      // 粉色 - 关键字（SELECT, FROM, WHERE）
    static let sqlFunction = Color(hex: "50FA7B")     // 绿色 - 函数（COUNT, SUM, MAX）
    static let sqlString = Color(hex: "F1FA8C")       // 黄色 - 字符串
    static let sqlNumber = Color(hex: "BD93F9")       // 紫色 - 数字
    static let sqlComment = Color(hex: "6272A4")      // 灰蓝 - 注释
    static let sqlOperator = Color(hex: "FF6E67")     // 橙红 - 操作符（=, >, <）
    static let sqlIdentifier = Color(hex: "8BE9FD")   // 青色 - 标识符（表名、列名）
    
    // === 分隔线（更细腻）===
    static let separator = Color(light: Color(hex: "E5E5EA"), dark: Color(hex: "3A3A3C"))
    static let border = Color(light: Color(hex: "D1D1D6"), dark: Color(hex: "48484A"))
    
    // === 交互状态（更微妙）===
    static let hover = Color(light: Color.black.opacity(0.04), dark: Color.white.opacity(0.06))
    static let pressed = Color(light: Color.black.opacity(0.08), dark: Color.white.opacity(0.1))
}

// MARK: - 设计系统 - 间距

/// 统一的间距（现代化设计 - 更宽松的呼吸感）
enum AppSpacing {
    static let xxs: CGFloat = 4   // 2 → 4
    static let xs: CGFloat = 6    // 4 → 6
    static let sm: CGFloat = 12   // 8 → 12
    static let md: CGFloat = 16   // 12 → 16
    static let lg: CGFloat = 20   // 16 → 20
    static let xl: CGFloat = 32   // 24 → 32
    static let xxl: CGFloat = 48  // 32 → 48
}

// MARK: - 设计系统 - 圆角

/// 统一的圆角（现代化设计 - 更大的圆角）
enum AppRadius {
    static let sm: CGFloat = 8   // 6 → 8
    static let md: CGFloat = 12  // 8 → 12
    static let lg: CGFloat = 16  // 12 → 16
    static let xl: CGFloat = 20  // 新增
}

// MARK: - 设计系统 - 字体排版

/// 统一的字体排版系统（现代化设计 - 更大更清晰）
enum AppTypography {
    // 标题字体（更大、更粗）
    static let title1 = Font.system(size: 24, weight: .bold)
    static let title2 = Font.system(size: 20, weight: .semibold)
    static let title3 = Font.system(size: 16, weight: .semibold)

    // 正文字体（提升到 14pt）
    static let body = Font.system(size: 14, weight: .regular)
    static let bodyMedium = Font.system(size: 14, weight: .medium)
    static let bodySemibold = Font.system(size: 14, weight: .semibold)

    // 辅助字体
    static let caption = Font.system(size: 12, weight: .regular)
    static let captionMedium = Font.system(size: 12, weight: .medium)
    static let small = Font.system(size: 11, weight: .regular)

    // 代码字体
    static let code = Font.system(size: 14, design: .monospaced)
    static let codeSmall = Font.system(size: 12, design: .monospaced)
}

// MARK: - 设计系统 - 动画

/// 统一的动画系统（流畅的交互反馈）
enum AppAnimation {
    /// 快速过渡（悬停、点击）- 200ms 弹性动画
    static let fast = Animation.spring(response: 0.2, dampingFraction: 0.8)

    /// 中速过渡（面板展开）- 300ms 弹性动画
    static let medium = Animation.spring(response: 0.3, dampingFraction: 0.75)

    /// 慢速过渡（页面切换）- 400ms 弹性动画
    static let slow = Animation.spring(response: 0.4, dampingFraction: 0.7)

    /// 弹性动画（按钮点击反馈）- 300ms 强弹性
    static let bouncy = Animation.spring(response: 0.3, dampingFraction: 0.6)

    /// 淡入淡出 - 200ms 线性
    static let fade = Animation.easeInOut(duration: 0.2)
}

// MARK: - 可复用组件 - 工具栏

/// 统一的工具栏组件
struct AppToolbar<Leading: View, Trailing: View>: View {
    let title: String?
    let icon: String?
    @ViewBuilder let leading: () -> Leading
    @ViewBuilder let trailing: () -> Trailing

    init(
        title: String? = nil,
        icon: String? = nil,
        @ViewBuilder leading: @escaping () -> Leading = { EmptyView() },
        @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() }
    ) {
        self.title = title
        self.icon = icon
        self.leading = leading
        self.trailing = trailing
    }

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            // 左侧内容
            leading()

            // 标题（如果有）
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundColor(AppColors.accent)
            }

            if let title = title {
                Text(title)
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(AppColors.primaryText)
            }

            Spacer()

            // 右侧内容
            trailing()
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.md)
        .background(.ultraThinMaterial)  // 毛玻璃效果
    }
}

// MARK: - 可复用组件 - 状态栏

/// 状态栏项
struct StatusItem {
    let icon: String?
    let text: String
    
    init(_ text: String, icon: String? = nil) {
        self.text = text
        self.icon = icon
    }
}

/// 统一的状态栏组件
struct AppStatusBar<Trailing: View>: View {
    let items: [StatusItem]
    @ViewBuilder let trailing: () -> Trailing

    init(items: [StatusItem], @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() }) {
        self.items = items
        self.trailing = trailing
    }

    var body: some View {
        HStack(spacing: AppSpacing.md) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                HStack(spacing: AppSpacing.xs) {
                    if let icon = item.icon {
                        Image(systemName: icon)
                            .font(.system(size: 10))
                    }
                    Text(item.text)
                }
            }

            Spacer()

            trailing()
        }
        .font(AppTypography.small)
        .foregroundColor(AppColors.secondaryText)
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.sm)
        .background(.ultraThinMaterial)  // 毛玻璃效果
    }
}

// MARK: - 可复用组件 - 按钮样式

/// 主要按钮样式（强调操作）
struct AppPrimaryButtonStyle: ButtonStyle {
    var isLoading: Bool = false
    @State private var isHovering = false

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: AppSpacing.xs) {
            if isLoading {
                ProgressView()
                    .controlSize(.small)
                    .tint(.white)
            }
            configuration.label
        }
        .font(AppTypography.caption)
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.md)
                .fill(configuration.isPressed ? AppColors.accent.opacity(0.8) : AppColors.accent)
        )
        .foregroundColor(.white)
        .scaleEffect(isHovering ? 1.02 : 1.0)
        .animation(AppAnimation.fast, value: isHovering)
        .onHover { isHovering = $0 }
    }
}

/// 次要按钮样式
struct AppSecondaryButtonStyle: ButtonStyle {
    @State private var isHovering = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTypography.caption)
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.sm)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.md)
                    .fill(configuration.isPressed ? AppColors.pressed : AppColors.hover)
            )
            .foregroundColor(AppColors.primaryText)
            .scaleEffect(isHovering ? 1.02 : 1.0)
            .animation(AppAnimation.fast, value: isHovering)
            .onHover { isHovering = $0 }
    }
}

/// 图标按钮样式（工具栏）
struct AppIconButtonStyle: ButtonStyle {
    var size: CGFloat = 28
    @State private var isHovering = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12))
            .foregroundColor(AppColors.secondaryText)
            .frame(width: size, height: size)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.sm)
                    .fill(configuration.isPressed ? AppColors.pressed : (isHovering ? AppColors.hover : Color.clear))
            )
            .scaleEffect(configuration.isPressed ? 0.95 : (isHovering ? 1.05 : 1.0))
            .animation(AppAnimation.bouncy, value: isHovering)
            .animation(AppAnimation.fast, value: configuration.isPressed)
            .onHover { isHovering = $0 }
    }
}

/// 文字按钮样式
struct AppTextButtonStyle: ButtonStyle {
    var color: Color = AppColors.accent
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(configuration.isPressed ? color.opacity(0.7) : color)
    }
}

// MARK: - 可复用组件 - 状态视图

/// 空状态视图
struct AppEmptyState: View {
    let icon: String
    let title: String
    var message: String? = nil
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            Image(systemName: icon)
                .font(.system(size: 48, weight: .light))
                .foregroundColor(AppColors.tertiaryText)

            Text(title)
                .font(AppTypography.title3)
                .foregroundColor(AppColors.secondaryText)

            if let message = message {
                Text(message)
                    .font(AppTypography.body)
                    .foregroundColor(AppColors.tertiaryText)
                    .multilineTextAlignment(.center)
            }

            if let actionTitle = actionTitle, let action = action {
                Button(actionTitle, action: action)
                    .buttonStyle(AppPrimaryButtonStyle())
                    .padding(.top, AppSpacing.sm)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.background)
    }
}

/// 加载状态视图
struct AppLoadingState: View {
    var message: String? = "加载中..."

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            ProgressView()
                .controlSize(.small)
            if let message = message {
                Text(message)
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.secondaryText)
            }
        }
        .padding(AppSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// 错误状态视图
struct AppErrorState: View {
    let message: String
    var onRetry: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 14))
                .foregroundColor(AppColors.error)

            Text(message)
                .font(AppTypography.caption)
                .foregroundColor(AppColors.error)
                .lineLimit(2)

            if let onRetry = onRetry {
                Spacer()
                Button("重试", action: onRetry)
                    .buttonStyle(AppTextButtonStyle())
            }
        }
        .padding(AppSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.error.opacity(0.08))
    }
}

// MARK: - 可复用组件 - 卡片

/// 卡片容器
struct AppCard<Content: View>: View {
    var hasBorder: Bool = true
    var isHoverable: Bool = true
    @ViewBuilder let content: () -> Content

    @State private var isHovering = false

    var body: some View {
        content()
            .padding(AppSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.md)
                    .fill(isHovering && isHoverable ? AppColors.hover : AppColors.secondaryBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.md)
                    .stroke(hasBorder ? AppColors.border : Color.clear, lineWidth: 0.5)
            )
            .scaleEffect(isHovering && isHoverable ? 1.005 : 1.0)
            .animation(AppAnimation.fast, value: isHovering)
            .onHover { isHovering = $0 }
    }
}

// MARK: - 可复用组件 - 分割线

/// 统一的分割线
struct AppDivider: View {
    var axis: Axis = .horizontal
    
    var body: some View {
        if axis == .horizontal {
            Rectangle()
                .fill(AppColors.separator)
                .frame(height: 0.5)
        } else {
            Rectangle()
                .fill(AppColors.separator)
                .frame(width: 0.5)
        }
    }
}

// MARK: - 可复用组件 - 列表项

/// 统一的列表项
struct AppListItem: View {
    let icon: String?
    let title: String
    var subtitle: String? = nil
    var isSelected: Bool = false
    var onTap: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundColor(isSelected ? .white : AppColors.secondaryText)
            }

            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text(title)
                    .font(isSelected ? AppTypography.bodyMedium : AppTypography.body)
                    .lineLimit(1)

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(AppTypography.small)
                        .foregroundColor(isSelected ? .white.opacity(0.7) : AppColors.tertiaryText)
                        .lineLimit(1)
                }
            }

            Spacer()
        }
        .padding(.vertical, AppSpacing.sm)
        .padding(.horizontal, AppSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.md)
                .fill(backgroundColor)
        )
        .foregroundColor(isSelected ? .white : AppColors.primaryText)
        .scaleEffect(isHovering && !isSelected ? 1.01 : 1.0)
        .animation(AppAnimation.fast, value: isHovering)
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
        .onTapGesture { onTap() }
    }

    private var backgroundColor: Color {
        if isSelected {
            return AppColors.accent
        }
        return isHovering ? AppColors.hover : Color.clear
    }
}

// MARK: - 可复用组件 - 徽章

/// 数量徽章
struct AppBadge: View {
    let count: Int

    var body: some View {
        Text("\(count)")
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(AppColors.secondaryText)
            .padding(.horizontal, AppSpacing.sm)
            .padding(.vertical, AppSpacing.xxs)
            .background(AppColors.tertiaryBackground)
            .clipShape(Capsule())
    }
}

// MARK: - 可复用组件 - 快捷键提示

/// 快捷键提示徽章
struct KeyboardShortcutHint: View {
    let keys: [String]
    @State private var isVisible = false

    init(_ keys: String...) {
        self.keys = keys
    }

    var body: some View {
        HStack(spacing: AppSpacing.xxs) {
            ForEach(keys, id: \.self) { key in
                Text(key)
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundColor(AppColors.secondaryText)
                    .padding(.horizontal, AppSpacing.xs)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(AppColors.tertiaryBackground)
                            .shadow(color: .black.opacity(0.1), radius: 1, y: 1)
                    )
            }
        }
        .padding(.horizontal, AppSpacing.sm)
        .padding(.vertical, AppSpacing.xs)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
        )
        .opacity(isVisible ? 1 : 0)
        .scaleEffect(isVisible ? 1.0 : 0.8)
        .animation(AppAnimation.bouncy, value: isVisible)
        .onAppear {
            withAnimation {
                isVisible = true
            }
        }
    }
}

// MARK: - 视图扩展（保持向后兼容）

extension View {
    /// 添加扁平化卡片样式
    func flatCard() -> some View {
        self
            .background(AppColors.secondaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
    }
    
    /// 添加分隔线
    func withBottomSeparator() -> some View {
        self.overlay(
            Rectangle()
                .fill(AppColors.separator)
                .frame(height: 0.5),
            alignment: .bottom
        )
    }
    
    /// 添加扁平选中效果
    func flatSelection(isSelected: Bool) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: AppRadius.md)
                    .fill(isSelected ? AppColors.accent : Color.clear)
            )
            .foregroundColor(isSelected ? .white : AppColors.primaryText)
    }
}

// MARK: - 旧的按钮样式（保持向后兼容）

/// 扁平化按钮样式
struct FlatButtonStyle: ButtonStyle {
    var isActive: Bool = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.sm)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.md)
                    .fill(backgroundColor(isPressed: configuration.isPressed))
            )
            .foregroundColor(isActive ? .white : AppColors.primaryText)
    }
    
    private func backgroundColor(isPressed: Bool) -> Color {
        if isActive {
            return isPressed ? AppColors.accent.opacity(0.8) : AppColors.accent
        }
        return isPressed ? AppColors.pressed : AppColors.hover
    }
}

/// 扁平化工具栏按钮
struct ToolbarButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, AppSpacing.sm)
            .padding(.vertical, AppSpacing.xs)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.sm)
                    .fill(configuration.isPressed ? AppColors.pressed : Color.clear)
            )
            .foregroundColor(AppColors.primaryText)
    }
}

// MARK: - 滚轮事件支持

/// 处理鼠标滚轮事件的 NSView 包装
struct ScrollWheelView: NSViewRepresentable {
    let onScroll: (Double) -> Void
    
    func makeNSView(context: Context) -> NSView {
        let view = ScrollWheelNSView()
        view.onScroll = onScroll
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        if let view = nsView as? ScrollWheelNSView {
            view.onScroll = onScroll
        }
    }
    
    class ScrollWheelNSView: NSView {
        var onScroll: ((Double) -> Void)?
        
        override func scrollWheel(with event: NSEvent) {
            // deltaY > 0 表示向上滚动（放大），< 0 表示向下滚动（缩小）
            let delta = event.deltaY > 0 ? 1.0 : (event.deltaY < 0 ? -1.0 : 0)
            if delta != 0 {
                onScroll?(delta)
            }
        }
    }
}

extension View {
    /// 添加滚轮事件支持
    func onScrollWheel(action: @escaping (Double) -> Void) -> some View {
        self.overlay(
            ScrollWheelView(onScroll: action)
                .allowsHitTesting(true)
        )
    }
}
