import Foundation // dates, formatting, and data types
import Testing // unit testing functions and expected results
import SwiftData // stores and loads saved notes
import PencilKit // apple pencil drawing tools and saved strokes
@testable import Pro_Calendar_Testing

@MainActor
/// tests that month drawings and page dimensions are saved separately
struct MonthDrawingPersistenceTests {
    // differentMonthsKeepSeparateInkAndPageDimensions() function
    /// a throwing test function that saves two month records and verifies their drawings and page sizes remain separate
    @Test func differentMonthsKeepSeparateInkAndPageDimensions() throws {
        // creates temporary in-memory storage for the test
        let container = try ModelContainer(
            for: DayNote.self, MonthNote.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        // creates a stroke at a known position to check after saving
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
        // saves a drawing for November and an empty drawing for December
        context.insert(MonthNote(monthKey: "2026-11", drawingData: drawing.dataRepresentation(), pageWidth: 1000, pageHeight: 700))
        context.insert(MonthNote(monthKey: "2026-12", drawingData: PKDrawing().dataRepresentation(), pageWidth: 800, pageHeight: 600))
        try context.save()

        // loads records through a new context to check the stored data
        let reloaded = try ModelContext(container).fetch(FetchDescriptor<MonthNote>())
        // gets each month record and requires both records to exist
        let november = try #require(reloaded.first { $0.monthKey == "2026-11" })
        let december = try #require(reloaded.first { $0.monthKey == "2026-12" })
        let restored = try PKDrawing(data: november.drawingData)
        // checks the stroke count, position, page dimensions, and empty December drawing
        #expect(restored.strokes.count == 1)
        #expect(restored.strokes[0].path[0].location == CGPoint(x: 120, y: 160))
        #expect(november.pageSize == CGSize(width: 1000, height: 700))
        #expect(try PKDrawing(data: december.drawingData).strokes.isEmpty)
    }
}
