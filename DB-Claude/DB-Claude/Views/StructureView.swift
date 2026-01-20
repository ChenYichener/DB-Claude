import SwiftUI

struct StructureView: View {
    let table: String
    let driver: any DatabaseDriver
    
    @State private var ddl: String = ""
    @State private var isLoading: Bool = true
    @State private var errorMessage: String?
    
    var body: some View {
        VStack(spacing: 0) {
            if isLoading {
                AppLoadingState(message: "加载表结构...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = errorMessage {
                AppErrorState(message: error) {
                    Task { await loadDDL() }
                }
            } else {
                ScrollView {
                    VStack(alignment: .leading) {
                        Text(ddl)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(AppColors.primaryText)
                            .textSelection(.enabled)
                            .padding(AppSpacing.md)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .background(AppColors.background)
        .task {
            await loadDDL()
        }
    }
    
    private func loadDDL() async {
        isLoading = true
        errorMessage = nil
        do {
            ddl = try await driver.getDDL(for: table)
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            ddl = ""
            isLoading = false
        }
    }
}
