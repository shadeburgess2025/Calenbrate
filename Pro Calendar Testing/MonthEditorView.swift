//
//  MonthEditorView.swift
//  Calenbrate Testing
//
//  Created by Shade Burgess on 11/1/26.
//

import SwiftUI // views, controls, and state for the app interface
import SwiftData // stores and loads saved notes
import PencilKit // apple pencil drawing tools and saved strokes

/// displays the month drawing controls and saves changes during editing
struct MonthEditorView: View {
    // receives the month editing session and access to saved note storage
    let session: MonthEditingSession
    @Environment(\.modelContext) private var modelContext
    let onSave: (PKDrawing) -> Void
    @Environment(\.scenePhase) private var scenePhase
    // declares the current drawing, tool settings, save state, and pending autosave task
    @State private var drawing: PKDrawing
    @State private var selectedTool: DrawingTool = .pen
    @State private var selectedColor: Color = .black
    @State private var penWidth: CGFloat = 3
    @State private var previousTool: DrawingTool?
    @State private var saveError: String?
    @State private var autosaveTask: Task<Void, Never>?
    @State private var hasUnsavedChanges = false

    // initializer
    /// accepts an editing session and save callback, then loads the starting drawing into state
    init(session: MonthEditingSession, onSave: @escaping (PKDrawing) -> Void) {
        self.session = session
        self.onSave = onSave
        _drawing = State(initialValue: session.drawing)
        _penWidth = State(initialValue: session.penWidth)
    }

    var body: some View {
        // displays the month canvas with the current drawing and pen settings
        ZoomableMonthBoard(
            month: session.month,
            pageSize: session.pageSize,
            drawing: $drawing,
            selectedTool: selectedTool,
            selectedColor: selectedColor,
            penWidth: penWidth
        )
        // temporarily selects the eraser while the pencil is squeezed
        .onPencilSqueeze { phase in
            switch phase {
            case .active:
                if previousTool == nil {
                    previousTool = selectedTool
                    selectedTool = .eraser
                }
            // restores the previous tool when the squeeze ends or is cancelled
            case .ended, .failed:
                if let previousTool { selectedTool = previousTool }
                previousTool = nil
            @unknown default:
                break
            }
        }
        // displays the shared drawing toolbar without moving the calendar layout
        .overlay(alignment: .bottom) {
            DrawingToolbar(selectedTool: $selectedTool, selectedColor: $selectedColor, penWidth: $penWidth)
                .padding(.bottom, 16)
        }
        .overlay(alignment: .topLeading) {
            // saves the drawing and returns to browsing only if saving succeeds
            Button("Save", systemImage: "checkmark") {
                autosaveTask?.cancel()
                if saveDrawing() { onSave(drawing) }
            }
            .buttonStyle(.bordered)
            .padding(.leading, 30)
            .accessibilityIdentifier("saveMonth")
        }
        // schedules saving when either the drawing or pen size changes
        .onChange(of: drawing) { _, _ in
            scheduleAutosave()
        }
        .onChange(of: penWidth) { _, _ in
            scheduleAutosave()
        }
        // saves pending changes when the app stops being active
        .onChange(of: scenePhase) { _, phase in
            if phase != .active && hasUnsavedChanges {
                autosaveTask?.cancel()
                _ = saveDrawing()
            }
        }
        // cancels the pending timer and saves remaining changes when the editor closes
        .onDisappear {
            autosaveTask?.cancel()
            if hasUnsavedChanges { _ = saveDrawing() }
        }
        // displays the saving error and lets the user retry or continue editing
        .alert("Couldn't save month drawing", isPresented: Binding(
            get: { saveError != nil },
            set: { if !$0 { saveError = nil } }
        )) {
            Button("Retry") { _ = saveDrawing() }
            Button("Keep Editing", role: .cancel) { saveError = nil }
        } message: {
            Text(saveError ?? "")
        }
    }

    // scheduleAutosave() function
    /// a void function that marks changes and replaces the pending save timer
    private func scheduleAutosave() {
        hasUnsavedChanges = true
        autosaveTask?.cancel()
        // waits 700 milliseconds after the last change before saving
        autosaveTask = Task { @MainActor in
            do { try await Task.sleep(for: .milliseconds(700)) }
            catch { return }
            guard !Task.isCancelled else { return }
            _ = saveDrawing()
        }
    }

    // saveDrawing() function
    /// a boolean returning function that saves the month drawing and page size, returning true if saving succeeds
    @discardableResult
    private func saveDrawing() -> Bool {
        do {
            let key = MonthIdentity.key(for: session.month)
            // searches for a saved record with this month key
            let descriptor = FetchDescriptor<MonthNote>(predicate: #Predicate { $0.monthKey == key })
            let note: MonthNote
            // uses the existing record if this month has already been saved
            if let existing = try modelContext.fetch(descriptor).first {
                note = existing
            } else {
                // creates a record with the original page dimensions for a new month drawing
                note = MonthNote(
                    monthKey: key,
                    drawingData: drawing.dataRepresentation(),
                    pageWidth: Double(session.pageSize.width),
                    pageHeight: Double(session.pageSize.height)
                )
                modelContext.insert(note)
            }
            // updates the saved stroke data and writes the record to storage
            note.drawingData = drawing.dataRepresentation()
            // saves the month pen size independently of the day notes
            note.penWidth = Double(penWidth)
            try modelContext.save()
            // clears the unsaved state and previous error after saving succeeds
            hasUnsavedChanges = false
            saveError = nil
            return true
        } catch {
            saveError = error.localizedDescription
            return false
        }
    }
}
