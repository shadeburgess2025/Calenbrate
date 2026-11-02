//
//  ContentView.swift
//  Pro Calendar Testing
//
//  Created by Shade Burgess on 10/23/26.
//

import SwiftUI
import SwiftData

// What I want to do next:
// - Add support for the apple pencil drawings
// - Make each calendar view into its own drawing board with zooming allowed
// - Add a liquid glass thing for the apple pencil features
// - Add a settings page and adjust the dark and light mode default colors
// - Add the ability to quick change the month and year
// - Make each day into its own blank drawing board that saves
// - Add transition into a days drawing board
//      - I want the transition to be a liquid glass feature that starts at the
//        center of the day chosen, then grows out to full screen (maybe with the
//        art on it)
// - Maybe add ability to change the size of individual days drawing boards
// - Add title/loading screen and background stuff


struct ContentView: View {
    var body: some View {
        NavigationStack {
            CalendarView()
                .toolbar(.hidden, for: .navigationBar)
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [DayNote.self, MonthNote.self], inMemory: true)
}
