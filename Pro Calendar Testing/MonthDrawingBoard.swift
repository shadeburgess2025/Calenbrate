//
//  MonthDrawingBoard.swift
//  Pro Calendar Testing
//
//  Created by Shade Burgess on 11/1/26.
//

import SwiftUI
import PencilKit

struct MonthDrawingBoard: UIViewRepresentable {
    var selectedTool: DrawingTool
    @Binding var drawing: PKDrawing

    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()

        // Load the initial drawing before attaching its delegate.
        canvas.drawing = drawing
        canvas.delegate = context.coordinator

        canvas.drawingPolicy = .pencilOnly

        // Let the calendar underneath remain visible.
        canvas.backgroundColor = .clear
        canvas.isOpaque = false

        // Keep strokes aligned with the calendar.
        canvas.isScrollEnabled = false
        canvas.minimumZoomScale = 1
        canvas.maximumZoomScale = 1
        canvas.zoomScale = 1
        canvas.contentInsetAdjustmentBehavior = .never

        return canvas
    }

    func updateUIView(
        _ uiView: PKCanvasView,
        context: Context
    ) {
        context.coordinator.drawing = $drawing

        // Apply the selected drawing tool.
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

        // Apply drawings loaded by the parent view.
        if uiView.drawing != drawing {
            uiView.drawing = drawing
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(drawing: $drawing)
    }

    class Coordinator: NSObject, PKCanvasViewDelegate {
        var drawing: Binding<PKDrawing>

        init(drawing: Binding<PKDrawing>) {
            self.drawing = drawing
        }

        // Send new or erased strokes back to SwiftUI.
        func canvasViewDrawingDidChange(
            _ canvasView: PKCanvasView
        ) {
            let updatedDrawing = canvasView.drawing

            guard drawing.wrappedValue != updatedDrawing else {
                return
            }

            drawing.wrappedValue = updatedDrawing
        }
    }
}
