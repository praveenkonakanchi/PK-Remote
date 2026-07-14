import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            DevicesView()
                .tabItem { Label("Devices", systemImage: "tv") }

            RemoteView()
                .tabItem { Label("Remote", systemImage: "dot.radiowaves.left.and.right") }

            STBModeView()
                .tabItem { Label("STB Mode", systemImage: "rectangle.grid.2x2") }
        }
        .tint(.indigo)
    }
}

#Preview("Light") { ContentView() }
#Preview("Dark") { ContentView().preferredColorScheme(.dark) }
