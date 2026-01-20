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
    
    // === 分隔线（更细腻）===
    static let separator = Color(light: Color(hex: "E5E5EA"), dark: Color(hex: "3A3A3C"))
    static let border = Color(light: Color(hex: "D1D1D6"), dark: Color(hex: "48484A"))
    
    // === 交互状态（更微妙）===
    static let hover = Color(light: Color.black.opacity(0.04), dark: Color.white.opacity(0.06))
    static let pressed = Color(light: Color.black.opacity(0.08), dark: Color.white.opacity(0.1))
}

// MARK: - 设计系统 - 间距

/// 统一的间距（更宽松）
enum AppSpacing {
    static let xxs: CGFloat = 2
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
}

// MARK: - 设计系统 - 圆角

/// 统一的圆角
enum AppRadius {
    static let sm: CGFloat = 6
    static let md: CGFloat = 8
    static let lg: CGFloat = 12
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
                    .font(.system(size: 12))
                    .foregroundColor(AppColors.accent)
            }
            
            if let title = title {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppColors.primaryText)
            }
            
            Spacer()
            
            // 右侧内容
            trailing()
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.sm)
        .background(AppColors.secondaryBackground)
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
        .font(.system(size: 11))
        .foregroundColor(AppColors.secondaryText)
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.sm)
        .background(AppColors.secondaryBackground)
    }
}

// MARK: - 可复用组件 - 按钮样式

/// 主要按钮样式（强调操作）
struct AppPrimaryButtonStyle: ButtonStyle {
    var isLoading: Bool = false
    
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: AppSpacing.xs) {
            if isLoading {
                ProgressView()
                    .controlSize(.small)
                    .tint(.white)
            }
            configuration.label
        }
        .font(.system(size: 12, weight: .medium))
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.md)
                .fill(configuration.isPressed ? AppColors.accent.opacity(0.8) : AppColors.accent)
        )
        .foregroundColor(.white)
    }
}

/// 次要按钮样式
struct AppSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.sm)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.md)
                    .fill(configuration.isPressed ? AppColors.pressed : AppColors.hover)
            )
            .foregroundColor(AppColors.primaryText)
    }
}

/// 图标按钮样式（工具栏）
struct AppIconButtonStyle: ButtonStyle {
    var size: CGFloat = 28
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12))
            .foregroundColor(AppColors.secondaryText)
            .frame(width: size, height: size)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.sm)
                    .fill(configuration.isPressed ? AppColors.pressed : AppColors.hover)
            )
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
        VStack(spacing: AppSpacing.md) {
            Image(systemName: icon)
                .font(.system(size: 32, weight: .light))
                .foregroundColor(AppColors.tertiaryText)
            
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(AppColors.secondaryText)
            
            if let message = message {
                Text(message)
                    .font(.system(size: 12))
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
                    .font(.system(size: 12))
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
                .font(.system(size: 12))
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
            .padding(AppSpacing.sm)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.md)
                    .fill(isHovering && isHoverable ? AppColors.hover : AppColors.secondaryBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.md)
                    .stroke(hasBorder ? AppColors.border : Color.clear, lineWidth: 0.5)
            )
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
                    .font(.system(size: 12))
                    .foregroundColor(isSelected ? .white : AppColors.secondaryText)
            }
            
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text(title)
                    .font(.system(size: 13, weight: isSelected ? .medium : .regular))
                    .lineLimit(1)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: 11))
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
