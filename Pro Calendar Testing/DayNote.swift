//
//  DayNote.swift
//  Calenbrate Testing
//
//  Created by Shade Burgess on 11/1/26.
//

import Foundation // dates, formatting, and data types
import SwiftData // stores and loads saved notes

@Model
/// stores the unique day key and the saved drawing data for that day
final class DayNote {
    // prevents multiple saved records from using the same day key
    @Attribute(.unique)
    var dayKey: String
    
    // allows SwiftData to store the drawing bytes outside the main database record
    @Attribute(.externalStorage)
    var drawingData: Data
    
    // stores this day's pen size and supplies a default for older notes
    var penWidth: Double = 3

    // initializer
    /// accepts and stores the day key and drawing data
    init(dayKey: String, drawingData: Data, penWidth: Double = 3) {
        self.dayKey = dayKey
        self.drawingData = drawingData
        self.penWidth = penWidth
    }
}
