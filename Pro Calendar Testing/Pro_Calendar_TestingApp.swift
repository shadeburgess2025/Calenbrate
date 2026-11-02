//
//  Pro_Calendar_TestingApp.swift
//  Pro Calendar Testing
//
//  Created by Shade Burgess on 10/23/26.
//

import SwiftUI
import SwiftData

@main
struct Pro_Calendar_TestingApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [DayNote.self, MonthNote.self])
    }
}
