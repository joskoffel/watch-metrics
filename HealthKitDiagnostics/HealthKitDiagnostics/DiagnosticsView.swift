import SwiftUI

struct DiagnosticsView: View {
    @State private var diagnostics = HeartbeatSeriesDiagnostics()

    var body: some View {
        ScrollView {
            Text(diagnostics.statusText)
                .multilineTextAlignment(.center)
                .padding()
        }
        .task {
            await diagnostics.run()
        }
    }
}
