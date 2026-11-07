//
//  DrawingToolbar.swift
//  Calenbrate Testing
//
//  Created by Shade Burgess on 11/1/26.
//

import SwiftUI // views, controls, and state for the app interface

/// displays the tool picker, color picker, and pen size slider for both drawing screens
struct DrawingToolbar: View {
    // connects the toolbar controls to the parent view tool, color, and width values
    @Binding var selectedTool: DrawingTool
    @Binding var selectedColor: Color
    @Binding var penWidth: CGFloat

    var body: some View {
        HStack(spacing: 12) {
            // displays the pen, eraser, and lasso choices
            Picker("Drawing tool", selection: $selectedTool) {
                Image(systemName: "pencil.tip")
                    .accessibilityLabel("Pen")
                    .tag(DrawingTool.pen)
    
                Image(systemName: "eraser")
                    .accessibilityLabel("Eraser")
                    .tag(DrawingTool.eraser)
                
                Image(systemName: "lasso")
                    .accessibilityLabel("Lasso")
                    .tag(DrawingTool.lasso)
            }
            .pickerStyle(.segmented)
            .controlSize(.large)
            .frame(width: 180)

            // lets the user choose the ink color and opacity
            ColorPicker("Ink color", selection: $selectedColor, supportsOpacity: true)
                .labelsHidden()
                .accessibilityLabel("Ink color")

            // displays the current pen size above the size slider
            VStack(spacing: 4) {
                Text("Size \(penWidth, specifier: "%.1f")")
                    .font(.caption)
                    .monospacedDigit()

                // changes the pen width from 1 to 20 in increments of 0.5
                Slider(value: $penWidth, in: 1...20, step: 0.5)
                    .accessibilityLabel("Pen size")
            }
            .frame(width: 120)
            // only allows pen size changes when the pen is selected
            .disabled(selectedTool != .pen)
        }
        .padding(8)
        .toolbarBackground()
    }
}

extension View {
    // toolbarBackground() function
    /// a view returning function that applies glass to the toolbar, or a material background on older iOS versions
    @ViewBuilder
    func toolbarBackground() -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(
                .regular,
                in: RoundedRectangle(cornerRadius: 20)
            )
        } else {
            self.background(.regularMaterial, in: Capsule())
        }
    }
}
