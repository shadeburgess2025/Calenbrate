//
//  MonthNote.swift
//  Calenbrate Testing
//
//  Created by Shade Burgess on 11/1/26.
//

import Foundation // dates, formatting, and data types
import SwiftData // stores and loads saved notes
import CoreGraphics // page sizes and drawing coordinates

@Model
/// stores the unique month key, drawing data, and original page dimensions
final class MonthNote {
    // prevents two records from using the same month key
    @Attribute(.unique) var monthKey: String
    // allows the drawing bytes to be stored separately from the database record
    @Attribute(.externalStorage) var drawingData: Data
    // stores the original page dimensions so the drawing keeps its alignment
    var pageWidth: Double
    var pageHeight: Double

    // stores this month's pen size separately from the day notes
    var penWidth: Double = 3

    // initializer
    /// accepts and stores the month key, drawing data, and original page dimensions
    init(monthKey: String, drawingData: Data, pageWidth: Double, pageHeight: Double, penWidth: Double = 3) {
        self.monthKey = monthKey
        self.drawingData = drawingData
        self.pageWidth = pageWidth
        self.pageHeight = pageHeight
        self.penWidth = penWidth
    }

    // returns the saved width and height as a page size
    var pageSize: CGSize {
        CGSize(width: pageWidth, height: pageHeight)
    }
}

/// provides a consistent year and month key for saved month drawings
enum MonthIdentity {
    // key() function
    /// a string returning function that accepts a date and formats its year and month as the record key
    static func key(for date: Date) -> String {
        // formats the date as a Gregorian year and month using the current time zone
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: date)
    }
}
