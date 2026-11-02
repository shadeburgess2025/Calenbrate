//
//  DayView.swift
//  Pro Calendar Testing
//
//  Created by Shade Burgess on 10/25/26.
//

import SwiftUI
import PencilKit
import SwiftData

extension View {
    @ViewBuilder
    func buttonBackground(isSelected: Bool, namespace: Namespace.ID) -> some View {
        self.background {
            if isSelected {
                let shape = RoundedRectangle(cornerRadius: 20)
                
                if #available(iOS 26.0, *) {
                    shape
                        .fill(Color.clear)
                        .glassEffect(.regular, in: shape)
                        .glassEffectID("toolSelection", in: namespace)
                } else {
                    shape
                        .fill(.regularMaterial)
                        .matchedGeometryEffect(id: "toolSelection", in: namespace)
                }
            }
        }
    }
    
    @ViewBuilder
    func toolGlassContainer() -> some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: 16) {
                self
            }
        } else {
            self
        }
    }
}

struct DayView: View {
    let date: Date
    @State private var selectedTool: DrawingTool = .pen
    @State private var selectedColor: Color = .black
    @State private var prevTool: DrawingTool? = nil
    @Namespace private var toolNamespace
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    @State private var drawing = PKDrawing()
    @State private var savedDay: DayNote?
    @State private var storageError: String?
        
    var body: some View {
        ZStack {
            Color.gray.opacity(0.15)
                .ignoresSafeArea()
            
            DrawingBoard(
                selectedTool: selectedTool,
                selectedColor: selectedColor,
                drawing: $drawing
            )
                .onPencilSqueeze { phase in
                    switch phase {
                    case .active:
                            if prevTool == nil {
                                prevTool = selectedTool
                                selectedTool = .eraser
                            }

                    case .ended:
                        if let previousTool = prevTool {
                            selectedTool = previousTool
                            prevTool = nil
                        }

                    case .failed:
                        if let previousTool = prevTool {
                            selectedTool = previousTool
                            prevTool = nil
                        }

                    @unknown default:
                        break
                    }
                }
                .disabled(savedDay == nil)
        }
        .overlay(alignment: .bottom) {
            DrawingToolbar(selectedTool: $selectedTool, selectedColor: $selectedColor)
                .padding(.bottom, 16)
        }
        .overlay(alignment: .top) {
            if let storageError {
                Text(storageError)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding()
                    .background(.regularMaterial)
            }
        }
        .navigationTitle(date.formatted(.dateTime.month(.wide).day().year()))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .task {
            do {
                try loadDay()
            } catch {
                storageError = error.localizedDescription
            }
        }
        .onDisappear {
            saveIfLoaded()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase != .active {
                saveIfLoaded()
            }
        }
    }
    
    private var dayKey: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
    
    private func loadDay() throws {
        guard savedDay == nil else { return }

        let key = dayKey

        let descriptor = FetchDescriptor<DayNote>(
            predicate: #Predicate { note in
                note.dayKey == key
            }
        )

        if let existing = try modelContext.fetch(descriptor).first {
            let restoredDrawing = try PKDrawing(
                data: existing.drawingData
            )

            drawing = restoredDrawing
            savedDay = existing
        } else {
            let newDay = DayNote(
                dayKey: key,
                drawingData: drawing.dataRepresentation()
            )

            modelContext.insert(newDay)
            savedDay = newDay
        }
    }
    
    private func saveDay() throws {
        guard let savedDay else { return }

        savedDay.drawingData = drawing.dataRepresentation()
        try modelContext.save()
    }
    
    private func saveIfLoaded() {
        guard savedDay != nil else { return }

        do {
            try saveDay()
            storageError = nil
        } catch {
            storageError = error.localizedDescription
        }
    }
}
