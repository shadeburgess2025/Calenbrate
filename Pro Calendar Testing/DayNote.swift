//
//  DayNote.swift
//  Pro Calendar Testing
//
//  Created by Shade Burgess on 11/1/26.
//

import Foundation
import SwiftData

@Model
final class DayNote {
    @Attribute(.unique)
    var dayKey: String
    
    @Attribute(.externalStorage)
    var drawingData: Data
    
    init(dayKey: String, drawingData: Data) {
        self.dayKey = dayKey
        self.drawingData = drawingData
    }
}
