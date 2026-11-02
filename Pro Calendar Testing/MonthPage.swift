//
//  ContentView.swift
//  Pro Calendar Testing
//
//  Created by Shade Burgess on 11/1/26.
//

import SwiftUI
import SwiftData
import PencilKit

/// A separate query for each page prevents neighboring months sharing one drawing.
struct MonthPage: View {
    let month: Date
    let viewportSize: CGSize
    let canEdit: Bool
    @Binding var isEditing: Bool
    @Query private var notes: [MonthNote]
    @State private var editor: MonthEditingSession?
    @State private var loadError: String?
    @State private var inkImage: UIImage?
    @Environment(\.displayScale) private var displayScale

    init(month: Date, viewportSize: CGSize, isEditing: Binding<Bool>, canEdit: Bool) {
        self.month = month
        self.viewportSize = viewportSize
        self.canEdit = canEdit
        _isEditing = isEditing
        let key = MonthIdentity.key(for: month)
        _notes = Query(filter: #Predicate<MonthNote> { $0.monthKey == key })
    }

    private var pageSize: CGSize {
        let size = notes.first?.pageSize ?? viewportSize
        return CGSize(width: max(1, size.width), height: max(1, size.height))
    }

    var body: some View {
        let size = pageSize
        let scale = min(viewportSize.width / size.width, viewportSize.height / size.height)

        ZStack {
            if let session = editor {
                MonthEditorView(session: session) { savedDrawing in
                    // Refresh before switching branches, avoiding a flash of stale ink.
                    renderInk(savedDrawing)
                    editor = nil
                    isEditing = false
                }
                .id(session.id)
            } else {
                ZStack {
                    MonthCalendarLayout(month: month)
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
        .task(id: notes.first?.drawingData) {
            if editor == nil { refreshInk() }
        }
        .alert("Unable to open month drawing", isPresented: Binding(
            get: { loadError != nil },
            set: { if !$0 { loadError = nil } }
        )) {
            Button("OK", role: .cancel) { loadError = nil }
        } message: {
            Text(loadError ?? "")
        }
    }

    private func refreshInk() {
        guard let data = notes.first?.drawingData else {
            inkImage = nil
            return
        }
        do {
            let drawing = try PKDrawing(data: data)
            renderInk(drawing)
        } catch {
            // Never replace an unreadable saved drawing with a blank one.
            loadError = error.localizedDescription
        }
    }

    private func renderInk(_ drawing: PKDrawing) {
        inkImage = drawing.strokes.isEmpty ? nil : drawing.image(
            from: CGRect(origin: .zero, size: pageSize), scale: displayScale
        )
    }

    private func openEditor() {
        do {
            let drawing = try notes.first.map { try PKDrawing(data: $0.drawingData) } ?? PKDrawing()
            editor = MonthEditingSession(month: month, pageSize: pageSize, drawing: drawing)
            isEditing = true
        } catch {
            loadError = error.localizedDescription
        }
    }
}

struct MonthEditingSession: Identifiable {
    let id = UUID()
    let month: Date
    let pageSize: CGSize
    let drawing: PKDrawing
}
