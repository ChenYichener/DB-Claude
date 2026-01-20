import SwiftUI

/// UPDATE/DELETE 确认对话框
/// 在执行危险操作前显示预览和确认
struct UpdateConfirmView: View {
    let sql: String
    let previewSQL: String  // 转换后的预览 SELECT 语句
    let affectedCount: Int
    let onConfirm: () -> Void
    let onCancel: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    private var isUpdate: Bool {
        sql.uppercased().trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("UPDATE ")
    }
    
    private var operationType: String {
        isUpdate ? "UPDATE" : "DELETE"
    }
    
    private var warningColor: Color {
        isUpdate ? .orange : .red
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            headerSection
            
            Divider()
            
            // SQL 预览
            sqlPreviewSection
            
            // 预览查询 SQL
            if !previewSQL.isEmpty {
                previewQuerySection
            }
            
            Divider()
            
            // 按钮区
            buttonSection
        }
        .frame(minWidth: 500, maxWidth: 700, minHeight: 250, maxHeight: 400)
    }
    
    // MARK: - 子视图
    
    private var headerSection: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 24))
                .foregroundColor(warningColor)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("\(operationType) 操作确认")
                    .font(.headline)
                
                Text("此操作将影响 \(affectedCount) 行数据")
                    .font(.subheadline)
                    .foregroundColor(affectedCount > 0 ? warningColor : .secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(warningColor.opacity(0.1))
    }
    
    private var sqlPreviewSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("将要执行的 SQL:")
                .font(.caption)
                .foregroundColor(.secondary)
            
            ScrollView(.horizontal, showsIndicators: true) {
                Text(sql)
                    .font(.system(size: 12, design: .monospaced))
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .background(Color(nsColor: .textBackgroundColor))
            .cornerRadius(6)
            .frame(maxHeight: 80)
        }
        .padding()
    }
    
    private var previewQuerySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("预览查询 (用于检查受影响的行数):")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                // 复制按钮
                Button(action: {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(previewSQL, forType: .string)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 10))
                        Text("复制")
                            .font(.system(size: 10))
                    }
                    .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("复制预览 SQL")
            }
            
            ScrollView(.horizontal, showsIndicators: true) {
                Text(previewSQL)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.primary)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(6)
            .frame(maxHeight: 60)
        }
        .padding(.horizontal)
        .padding(.bottom)
    }
    
    private var buttonSection: some View {
        HStack {
            Button("取消") {
                onCancel()
                dismiss()
            }
            .keyboardShortcut(.escape, modifiers: [])
            
            Spacer()
            
            if affectedCount == 0 {
                Text("没有数据会被影响")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Button(affectedCount > 0 ? "确认执行 (\(affectedCount) 行)" : "确认执行") {
                onConfirm()
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .tint(warningColor)
            .keyboardShortcut(.return, modifiers: .command)
        }
        .padding()
    }
}
