//
//  Pro_Calendar_TestingApp.swift
//  Calenbrate Testing
//
//  Created by Shade Burgess on 10/23/26.
//

import SwiftUI // views, controls, and state for the app interface
import SwiftData // stores and loads saved notes

@main
/// starts the app and provides storage for day and month notes
struct Pro_Calendar_TestingApp: App {
    var body: some Scene {
        // opens the main calendar interface
        WindowGroup {
            ContentView()
        }
        // provides persistent storage for both day and month note records
        .modelContainer(for: [DayNote.self, MonthNote.self])
    }
}
