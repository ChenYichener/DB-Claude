import SwiftUI

/// 危险操作开关组件
/// 用于控制 UPDATE/DELETE/ALTER 等危险操作的权限
struct DangerToggle: View {
    let title: String
    @Binding var isOn: Bool
    let color: Color
    
    var body: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                isOn.toggle()
            }
        }) {
            HStack(spacing: 4) {
                Circle()
                    .fill(isOn ? color : Color.gray.opacity(0.3))
                    .frame(width: 6, height: 6)
                
                Text(title)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(isOn ? color : AppColors.tertiaryText)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(isOn ? color.opacity(0.15) : AppColors.hover)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(isOn ? color.opacity(0.5) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .help(isOn ? "点击禁用 \(title) 操作" : "点击允许 \(title) 操作")
    }
}
