import SwiftUI

struct MenuBarView: View {
    @State private var statusText = "Idle"
    @State private var isRecording = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("EchoLog").font(.headline)
            Text(statusText)
                .font(.caption)
                .foregroundStyle(.secondary)
            Divider()
            if isRecording {
                Button("Stop Recording") {
                    // Will be wired in Step 6
                }
            } else {
                Button("Start Recording") {
                    // Will be wired in Step 6
                }
            }
            Divider()
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding()
        .frame(width: 250)
    }
}
