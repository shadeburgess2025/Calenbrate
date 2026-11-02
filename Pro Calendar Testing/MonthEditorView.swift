//
//  ContentView.swift
//  Pro Calendar Testing
//
//  Created by Shade Burgess on 11/1/26.
//

import SwiftUI
import SwiftData
import PencilKit

struct MonthEditorView: View {
    let session: MonthEditingSession
    @Environment(\.modelContext) private var modelContext
    let onSave: (PKDrawing) -> Void
    @Environment(\.scenePhase) private var scenePhase
    @State private var drawing: PKDrawing
    @State private var selectedTool: DrawingTool = .pen
    @State private var selectedColor: Color = .black
    @State private var previousTool: DrawingTool?
    @State private var saveError: String?
    @State private var autosaveTask: Task<Void, Never>?
    @State private var hasUnsavedChanges = false

    init(session: MonthEditingSession, onSave: @escaping (PKDrawing) -> Void) {
        self.session = session
        self.onSave = onSave
        _drawing = State(initialValue: session.drawing)
    }

    var body: some View {
        ZoomableMonthBoard(
            month: session.month,
            pageSize: session.pageSize,
            drawing: $drawing,
            selectedTool: selectedTool,
            selectedColor: selectedColor
        )
        .onPencilSqueeze { phase in
            switch phase {
            case .active:
                if previousTool == nil {
                    previousTool = selectedTool
                    selectedTool = .eraser
                }
            case .ended, .failed:
                if let previousTool { selectedTool = previousTool }
                previousTool = nil
            @unknown default:
                break
            }
        }
        .overlay(alignment: .bottom) {
            DrawingToolbar(selectedTool: $selectedTool, selectedColor: $selectedColor)
                .padding(.bottom, 16)
        }
        .overlay(alignment: .topLeading) {
            Button("Save", systemImage: "checkmark") {
                autosaveTask?.cancel()
                if saveDrawing() { onSave(drawing) }
            }
            .buttonStyle(.bordered)
            .padding(.leading, 30)
            .accessibilityIdentifier("saveMonth")
        }
        .onChange(of: drawing) { _, _ in
            hasUnsavedChanges = true
            autosaveTask?.cancel()
            // Wait until a burst of drawing changes has settled before writing to disk.
            autosaveTask = Task { @MainActor in
                do { try await Task.sleep(for: .milliseconds(700)) }
                catch { return }
                guard !Task.isCancelled else { return }
                _ = saveDrawing()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active && hasUnsavedChanges {
                autosaveTask?.cancel()
                _ = saveDrawing()
            }
        }
        .onDisappear {
            autosaveTask?.cancel()
            if hasUnsavedChanges { _ = saveDrawing() }
        }
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

    @discardableResult
    private func saveDrawing() -> Bool {
        do {
            let key = MonthIdentity.key(for: session.month)
            let descriptor = FetchDescriptor<MonthNote>(predicate: #Predicate { $0.monthKey == key })
            let note: MonthNote
            if let existing = try modelContext.fetch(descriptor).first {
                note = existing
            } else {
                note = MonthNote(
                    monthKey: key,
                    drawingData: drawing.dataRepresentation(),
                    pageWidth: Double(session.pageSize.width),
                    pageHeight: Double(session.pageSize.height)
                )
                modelContext.insert(note)
            }
            note.drawingData = drawing.dataRepresentation()
            try modelContext.save()
            hasUnsavedChanges = false
            saveError = nil
            return true
        } catch {
            saveError = error.localizedDescription
            return false
        }
    }
}
