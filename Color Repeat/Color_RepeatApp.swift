//
//  Color_RepeatApp.swift
//  Color Repeat
//
//  Created by Jada Brunson on 9/10/24.
//

import SwiftUI
import SwiftData

@main
struct Color_RepeatApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(for: Item.self) // Setup SwiftData for Item model
        }
    }
}

