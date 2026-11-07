//
//  MonthPage.swift
//  Calenbrate Testing
//
//  Created by Shade Burgess on 11/1/26.
//

import SwiftUI // views, controls, and state for the app interface
import SwiftData // stores and loads saved notes
import PencilKit // apple pencil drawing tools and saved strokes

/// displays one month with its saved drawing and opens its editor when requested
struct MonthPage: View {
    // receives the month, available display size, and editing permissions
    let month: Date
    let viewportSize: CGSize
    let canEdit: Bool
    @Binding var isEditing: Bool
    // loads the saved record for this page and observes changes to it
    @Query private var notes: [MonthNote]
    // declares the editing session, loading error, and saved drawing image
    @State private var editor: MonthEditingSession?
    @State private var loadError: String?
    @State private var inkImage: UIImage?
    @Environment(\.displayScale) private var displayScale

    // initializer
    /// accepts the month, available size, editing binding, and permissions, then sets up the saved note query
    init(month: Date, viewportSize: CGSize, isEditing: Binding<Bool>, canEdit: Bool) {
        self.month = month
        self.viewportSize = viewportSize
        self.canEdit = canEdit
        _isEditing = isEditing
        // creates the month key and restricts the query to this month
        let key = MonthIdentity.key(for: month)
        _notes = Query(filter: #Predicate<MonthNote> { $0.monthKey == key })
    }

    // returns the saved page dimensions, or the available size for a new month
    private var pageSize: CGSize {
        let size = notes.first?.pageSize ?? viewportSize
        return CGSize(width: max(1, size.width), height: max(1, size.height))
    }

    var body: some View {
        let size = pageSize
        // calculates a scale that fits the whole saved page without changing its proportions
        let scale = min(viewportSize.width / size.width, viewportSize.height / size.height)

        ZStack {
            // displays the editor if an editing session is active
            if let session = editor {
                MonthEditorView(session: session) { savedDrawing in
                    // updates the displayed drawing before closing the editor
                    renderInk(savedDrawing)
                    editor = nil
                    isEditing = false
                }
                .id(session.id)
            } else {
                ZStack {
                    MonthCalendarLayout(month: month)
                    // displays saved strokes over the calendar without blocking day cell taps
                    if let inkImage {
                        Image(uiImage: inkImage)
                            .resizable()
                            .frame(width: size.width, height: size.height)
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                    }
                }
                .frame(width: size.width, height: size.height)
                .scaleEffect(max(0.001, scale))
                .frame(width: viewportSize.width, height: viewportSize.height)
                .overlay(alignment: .topLeading) {
                    // displays the edit button when this page can be edited
                    if canEdit {
                        Button("Edit", systemImage: "pencil.tip") { openEditor() }
                            .buttonStyle(.bordered)
                            .padding(.leading, 30)
                            .accessibilityIdentifier("editMonth")
                    }
                }
            }
        }
        .frame(width: viewportSize.width, height: viewportSize.height)
        // refreshes the saved drawing image when its data changes outside editing
        .task(id: notes.first?.drawingData) {
            if editor == nil { refreshInk() }
        }
        // displays an error if the saved drawing cannot be opened
        .alert("Unable to open month drawing", isPresented: Binding(
            get: { loadError != nil },
            set: { if !$0 { loadError = nil } }
        )) {
            Button("OK", role: .cancel) { loadError = nil }
        } message: {
            Text(loadError ?? "")
        }
    }

    // refreshInk() function
    /// a void function that loads the saved month drawing and updates its display image, or stores a loading error
    private func refreshInk() {
        // clears the display image if this month has no saved drawing
        guard let data = notes.first?.drawingData else {
            inkImage = nil
            return
        }
        do {
            let drawing = try PKDrawing(data: data)
            renderInk(drawing)
        } catch {
            loadError = error.localizedDescription
        }
    }

    // renderInk() function
    /// a void function that accepts a drawing and creates an image at the page size, leaving the image empty if there are no strokes
    private func renderInk(_ drawing: PKDrawing) {
        inkImage = drawing.strokes.isEmpty ? nil : drawing.image(
            from: CGRect(origin: .zero, size: pageSize), scale: displayScale
        )
    }

    // openEditor() function
    /// a void function that loads the month drawing and starts an editing session if the drawing can be read
    private func openEditor() {
        do {
            // loads saved strokes or creates an empty drawing before opening the editor
            let drawing = try notes.first.map { try PKDrawing(data: $0.drawingData) } ?? PKDrawing()
            editor = MonthEditingSession(
                month: month,
                pageSize: pageSize,
                drawing: drawing,
                penWidth: CGFloat(notes.first?.penWidth ?? 3)
            )
            isEditing = true
        } catch {
            loadError = error.localizedDescription
        }
    }
}

/// stores the month, page size, and starting drawing for one editing session
struct MonthEditingSession: Identifiable {
    let id = UUID()
    // receives the month, available display size, and editing permissions
    let month: Date
    let pageSize: CGSize
    let drawing: PKDrawing
    let penWidth: CGFloat
}
