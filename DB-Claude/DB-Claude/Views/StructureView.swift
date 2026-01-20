import SwiftUI

struct StructureView: View {
    let table: String
    let driver: any DatabaseDriver
    
    @State private var ddl: String = "Loading..."
    @State private var errorMessage: String?
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading) {
                if let error = errorMessage {
                    Text("Error: \(error)")
                        .foregroundStyle(.red)
                        .padding()
                }
                
                Text(ddl)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .padding()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .task {
            await loadDDL()
        }
    }
    
    private func loadDDL() async {
        do {
            ddl = try await driver.getDDL(for: table)
        } catch {
            errorMessage = error.localizedDescription
            ddl = ""
        }
    }
}
