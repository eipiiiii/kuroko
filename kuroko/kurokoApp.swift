//
//  kurokoApp.swift
//  kuroko
//
//  Created by 林栄介 on 2025/12/08.
//

import SwiftUI

@main
struct kurokoApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        
        #if os(macOS)
        Settings {
            SettingsView(sessionManager: SessionManager.shared)
        }
        #endif
    }
}
