//
//  ContentView.swift
//  Pro Calendar Testing
//
//  Created by Shade Burgess on 11/1/26.
//

import Foundation
import SwiftData
import CoreGraphics

@Model
final class MonthNote {
    @Attribute(.unique) var monthKey: String
    @Attribute(.externalStorage) var drawingData: Data
    var pageWidth: Double
    var pageHeight: Double

    init(monthKey: String, drawingData: Data, pageWidth: Double, pageHeight: Double) {
        self.monthKey = monthKey
        self.drawingData = drawingData
        self.pageWidth = pageWidth
        self.pageHeight = pageHeight
    }

    var pageSize: CGSize {
        CGSize(width: pageWidth, height: pageHeight)
    }
}

enum MonthIdentity {
    static func key(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: date)
    }
}
