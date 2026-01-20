import SwiftUI

/// Toast 提示视图组件
/// 用于显示临时的操作反馈信息
struct ToastView: View {
    let message: String
    
    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: "keyboard")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.9))
            
            Text(message)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white)
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.vertical, AppSpacing.sm)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.85))
                .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
        )
    }
}
