//
//  kurokoApp.swift
//  kuroko
//
//  Created by 林栄介 on 2025/12/08.
//

import SwiftUI

@main
struct kurokoApp: App {
    @State private var themeManager = ThemeManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(themeManager)
                .tint(themeManager.accentColor)
        }
    }
}
