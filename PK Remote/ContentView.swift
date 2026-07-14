import SwiftUI

struct ContentView: View {
    let appState: AppState

    var body: some View {
        TabView {
            DevicesView(appState: appState)
                .tabItem { Label("Devices", systemImage: "tv") }

            RemoteView(appState: appState)
                .tabItem { Label("Remote", systemImage: "dot.radiowaves.left.and.right") }

            STBModeView(appState: appState)
                .tabItem { Label("STB Mode", systemImage: "rectangle.grid.2x2") }
        }
        .tint(.indigo)
    }
}

#Preview("Light") { ContentView(appState: AppState()) }
#Preview("Dark") { ContentView(appState: AppState()).preferredColorScheme(.dark) }
