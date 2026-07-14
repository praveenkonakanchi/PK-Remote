//
//  PK_RemoteApp.swift
//  PK Remote
//
//  Created by PeeKay on 7/14/26.
//

import SwiftUI

@main
struct PK_RemoteApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView(appState: appState)
        }
    }
}
