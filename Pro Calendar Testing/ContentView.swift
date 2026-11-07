//
//  ContentView.swift
//  Calenbrate Testing
//
//  Created by Shade Burgess on 10/23/26.
//

import SwiftUI // views, controls, and state for the app interface
import SwiftData // stores and loads saved notes

/// displays the calendar and allows navigation into individual days
struct ContentView: View {
    var body: some View {
        // allows the calendar to open individual day screens
        NavigationStack {
            CalendarView()
                // hides the unused navigation bar on the calendar screen
                .toolbar(.hidden, for: .navigationBar)
        }
    }
}

// displays a preview using temporary storage when a model container is provided
#Preview {
    ContentView()
        .modelContainer(for: [DayNote.self, MonthNote.self], inMemory: true)
}
