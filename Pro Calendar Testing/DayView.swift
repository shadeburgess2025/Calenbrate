//
//  DayView.swift
//  Calenbrate Testing
//
//  Created by Shade Burgess on 10/25/26.
//

import SwiftUI // views, controls, and state for the app interface
import PencilKit // apple pencil drawing tools and saved strokes
import SwiftData // stores and loads saved notes

extension View {
    // buttonBackground() function
    /// a view returning function that accepts the selection state and animation namespace, then displays a background for the selected button
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
    
    // toolGlassContainer() function
    /// a view returning function that groups glass effects on supported iOS versions
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

/// displays the selected day drawing, drawing controls, and saving errors
struct DayView: View {
    // stores the selected date and declares the current drawing tool settings
    let date: Date
    @State private var selectedTool: DrawingTool = .pen
    @State private var selectedColor: Color = .black
    @State private var penWidth: CGFloat = 10
    @State private var prevTool: DrawingTool? = nil
    @Namespace private var toolNamespace
    
    // gets the note storage context and app activity state
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    // declares the current drawing, saved record, and error message
    @State private var drawing = PKDrawing()
    @State private var savedDay: DayNote?
    @State private var storageError: String?
        
    var body: some View {
        ZStack {
            Color.gray.opacity(0.15)
                .ignoresSafeArea()
            
            // displays the day drawing with the selected tool, color, and width
            DrawingBoard(
                selectedTool: selectedTool,
                selectedColor: selectedColor,
                penWidth: penWidth,
                drawing: $drawing
            )
                // temporarily selects the eraser while the pencil is squeezed
                .onPencilSqueeze { phase in
                    switch phase {
                    case .active:
                            if prevTool == nil {
                                prevTool = selectedTool
                                selectedTool = .eraser
                            }

                    // restores the previous tool when the squeeze ends
                    case .ended:
                        if let previousTool = prevTool {
                            selectedTool = previousTool
                            prevTool = nil
                        }

                    // restores the previous tool if the squeeze is cancelled
                    case .failed:
                        if let previousTool = prevTool {
                            selectedTool = previousTool
                            prevTool = nil
                        }

                    @unknown default:
                        break
                    }
                }
                // prevents drawing before the saved note finishes loading
                .disabled(savedDay == nil)
        }
        // displays the shared toolbar at the bottom of the drawing screen
        .overlay(alignment: .bottom) {
            DrawingToolbar(selectedTool: $selectedTool, selectedColor: $selectedColor, penWidth: $penWidth)
                .padding(.bottom, 16)
        }
        .overlay(alignment: .top) {
            // displays the storage error if loading or saving failed
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
        // loads the note when the day screen appears
        .task {
            do {
                try loadDay()
            } catch {
                storageError = error.localizedDescription
            }
        }
        // saves the drawing when the user leaves the day screen
        .onDisappear {
            saveIfLoaded()
        }
        // saves the drawing when the app stops being active
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase != .active {
                saveIfLoaded()
            }
        }
    }
    
    // returns a consistent year, month, and day string for the selected date
    private var dayKey: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
    
    // loadDay() function
    /// a throwing void function that loads the selected day drawing or creates a new record if the day has not been saved
    private func loadDay() throws {
        // prevents loading the same note again after it has already been opened
        guard savedDay == nil else { return }

        let key = dayKey

        // searches stored notes for the selected day key
        let descriptor = FetchDescriptor<DayNote>(
            predicate: #Predicate { note in
                note.dayKey == key
            }
        )

        // loads the existing drawing if a matching day record was found
        if let existing = try modelContext.fetch(descriptor).first {
            let restoredDrawing = try PKDrawing(
                data: existing.drawingData
            )

            drawing = restoredDrawing
            // restores the pen size saved with this day
            penWidth = CGFloat(existing.penWidth)
            savedDay = existing
        } else {
            // creates a new day record if no saved note was found
            let newDay = DayNote(
                dayKey: key,
                drawingData: drawing.dataRepresentation(),
                penWidth: Double(penWidth)
            )

            // adds the new record to the storage context
            modelContext.insert(newDay)
            savedDay = newDay
        }
    }
    
    // saveDay() function
    /// a throwing void function that converts the current drawing to data and saves it to the day record
    private func saveDay() throws {
        guard let savedDay else { return }

        // converts the drawing to data before saving it
        savedDay.drawingData = drawing.dataRepresentation()
        // saves the current pen size with the drawing
        savedDay.penWidth = Double(penWidth)
        try modelContext.save()
    }
    
    // saveIfLoaded() function
    /// a void function that saves the loaded day and stores an error message if saving fails
    private func saveIfLoaded() {
        // skips saving if the note has not loaded
        guard savedDay != nil else { return }

        do {
            try saveDay()
            storageError = nil
        } catch {
            storageError = error.localizedDescription
        }
    }
}
