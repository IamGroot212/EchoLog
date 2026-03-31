import SwiftUI

@main
struct EchoLogApp: App {
    var body: some Scene {
        MenuBarExtra("EchoLog", systemImage: "waveform") {
            MenuBarView()
        }
    }
}
