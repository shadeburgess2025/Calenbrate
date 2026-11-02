import Foundation
import Testing
import SwiftData
import PencilKit
@testable import Pro_Calendar_Testing

@MainActor
struct MonthDrawingPersistenceTests {
    @Test func differentMonthsKeepSeparateInkAndPageDimensions() throws {
        let container = try ModelContainer(
            for: DayNote.self, MonthNote.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        let point = PKStrokePoint(
            location: CGPoint(x: 120, y: 160), timeOffset: 0,
            size: CGSize(width: 3, height: 3), opacity: 1,
            force: 1, azimuth: 0, altitude: .pi / 2
        )
        let stroke = PKStroke(
            ink: PKInk(.pen, color: .blue),
            path: PKStrokePath(controlPoints: [point], creationDate: Date())
        )
        let drawing = PKDrawing(strokes: [stroke])
        context.insert(MonthNote(monthKey: "2026-11", drawingData: drawing.dataRepresentation(), pageWidth: 1000, pageHeight: 700))
        context.insert(MonthNote(monthKey: "2026-12", drawingData: PKDrawing().dataRepresentation(), pageWidth: 800, pageHeight: 600))
        try context.save()

        // Refetch through a different context so this checks stored data, not the original objects.
        let reloaded = try ModelContext(container).fetch(FetchDescriptor<MonthNote>())
        let november = try #require(reloaded.first { $0.monthKey == "2026-11" })
        let december = try #require(reloaded.first { $0.monthKey == "2026-12" })
        let restored = try PKDrawing(data: november.drawingData)
        #expect(restored.strokes.count == 1)
        #expect(restored.strokes[0].path[0].location == CGPoint(x: 120, y: 160))
        #expect(november.pageSize == CGSize(width: 1000, height: 700))
        #expect(try PKDrawing(data: december.drawingData).strokes.isEmpty)
    }
}
