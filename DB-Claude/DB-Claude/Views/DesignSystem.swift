import SwiftUI

// MARK: - 扁平化设计系统

/// 统一的颜色体系
enum AppColors {
    // 背景色
    static let background = Color(nsColor: .windowBackgroundColor)
    static let secondaryBackground = Color(nsColor: .controlBackgroundColor)
    static let tertiaryBackground = Color.gray.opacity(0.08)
    
    // 前景色
    static let primaryText = Color.primary
    static let secondaryText = Color.secondary
    static let tertiaryText = Color.gray
    
    // 强调色
    static let accent = Color.accentColor
    static let accentSubtle = Color.accentColor.opacity(0.12)
    static let accentMuted = Color.accentColor.opacity(0.2)
    
    // 状态色
    static let success = Color.green
    static let error = Color.red
    static let warning = Color.orange
    
    // 分割线
    static let separator = Color.gray.opacity(0.2)
    static let border = Color.gray.opacity(0.15)
    
    // 悬停状态
    static let hover = Color.gray.opacity(0.1)
    static let pressed = Color.gray.opacity(0.15)
}

/// 统一的间距
enum AppSpacing {
    static let xxs: CGFloat = 2
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
}

/// 统一的圆角
enum AppRadius {
    static let sm: CGFloat = 4
    static let md: CGFloat = 6
    static let lg: CGFloat = 8
}

// MARK: - 扁平化组件样式

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

// MARK: - 视图扩展

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
                .frame(height: 1),
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
