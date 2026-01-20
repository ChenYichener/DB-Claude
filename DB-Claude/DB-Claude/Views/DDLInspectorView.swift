import SwiftUI

struct DDLInspectorView: View {
    let tableName: String
    let ddl: String
    
    @State private var isCopied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 标题栏 - 扁平化
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "tablecells")
                    .font(.system(size: 14))
                    .foregroundColor(AppColors.accent)
                
                Text(tableName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppColors.primaryText)
                
                Spacer()
                
                // 复制按钮
                Button(action: copyDDL) {
                    HStack(spacing: AppSpacing.xxs) {
                        Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 11))
                        if isCopied {
                            Text("已复制")
                                .font(.system(size: 11))
                        }
                    }
                    .foregroundColor(isCopied ? AppColors.success : AppColors.secondaryText)
                    .padding(.horizontal, AppSpacing.sm)
                    .padding(.vertical, AppSpacing.xs)
                    .background(AppColors.tertiaryBackground)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.sm))
                }
                .buttonStyle(.plain)
                .help("复制 DDL")
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.sm)
            .background(AppColors.secondaryBackground)

            // DDL 内容 - 扁平化
            ScrollView(.vertical, showsIndicators: true) {
                Text(ddl)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(AppColors.primaryText)
                    .padding(AppSpacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .background(AppColors.background)
        }
        .frame(minWidth: 200, maxWidth: .infinity)
    }
    
    private func copyDDL() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(ddl, forType: .string)
        
        withAnimation {
            isCopied = true
        }
        
        // 2秒后重置状态
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                isCopied = false
            }
        }
    }
}

#Preview {
    DDLInspectorView(
        tableName: "users",
        ddl: "CREATE TABLE `users` (\n  `id` int NOT NULL AUTO_INCREMENT,\n  `name` varchar(255) NOT NULL,\n  `email` varchar(255) NOT NULL,\n  PRIMARY KEY (`id`)\n) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;"
    )
}
