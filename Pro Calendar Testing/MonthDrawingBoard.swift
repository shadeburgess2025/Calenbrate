//
//  MonthDrawingBoard.swift
//  Calenbrate Testing
//
//  Created by Shade Burgess on 11/1/26.
//

import SwiftUI // views, controls, and state for the app interface
import PencilKit // apple pencil drawing tools and saved strokes

/// provides a transparent drawing canvas with scrolling and zooming disabled
struct MonthDrawingBoard: UIViewRepresentable {
    // receives the selected tool and a binding to the current drawing
    var selectedTool: DrawingTool
    @Binding var drawing: PKDrawing

    // makeUIView() function
    /// a canvas returning function that creates a transparent drawing board and disables its independent scrolling and zooming
    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()

        // loads the initial drawing before connecting change notifications
        canvas.drawing = drawing
        canvas.delegate = context.coordinator

        canvas.drawingPolicy = .pencilOnly

        // makes the canvas transparent so the calendar remains visible
        canvas.backgroundColor = .clear
        canvas.isOpaque = false

        // disables independent canvas movement to keep strokes aligned with the calendar
        canvas.isScrollEnabled = false
        canvas.minimumZoomScale = 1
        canvas.maximumZoomScale = 1
        canvas.zoomScale = 1
        canvas.contentInsetAdjustmentBehavior = .never

        return canvas
    }

    // updateUIView() function
    /// a void function that updates the selected tool and applies a drawing loaded by the parent view
    func updateUIView(
        _ uiView: PKCanvasView,
        context: Context
    ) {
        context.coordinator.drawing = $drawing

        // sets the canvas tool to the selected pen, eraser, or lasso
        switch selectedTool {
        case .pen:
            uiView.tool = PKInkingTool(
                .pen,
                color: .black,
                width: 3
            )

        case .eraser:
            uiView.tool = PKEraserTool(.vector)
            
        case .lasso:
            uiView.tool = PKLassoTool()
        }

        // only replaces the canvas drawing if the parent supplied a different drawing
        if uiView.drawing != drawing {
            uiView.drawing = drawing
        }
    }

    // makeCoordinator() function
    /// a coordinator returning function that connects canvas changes to the parent drawing binding
    func makeCoordinator() -> Coordinator {
        Coordinator(drawing: $drawing)
    }

    /// stores the drawing binding and sends canvas changes back to SwiftUI
    class Coordinator: NSObject, PKCanvasViewDelegate {
        var drawing: Binding<PKDrawing>

        // initializer
        /// accepts and stores the parent drawing binding
        init(drawing: Binding<PKDrawing>) {
            self.drawing = drawing
        }

        // canvasViewDrawingDidChange() function
        /// a void function that sends changed strokes from the canvas back to the parent view
        func canvasViewDrawingDidChange(
            _ canvasView: PKCanvasView
        ) {
            let updatedDrawing = canvasView.drawing

            // prevents sending the same drawing back to the parent again
            guard drawing.wrappedValue != updatedDrawing else {
                return
            }

            drawing.wrappedValue = updatedDrawing
        }
    }
}
