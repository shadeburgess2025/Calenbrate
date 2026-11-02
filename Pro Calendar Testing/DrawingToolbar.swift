//
//  DrawingToolbar.swift
//  Pro Calendar Testing
//
//  Created by Shade Burgess on 11/1/26.
//

import SwiftUI

struct DrawingToolbar: View {
    @Binding var selectedTool: DrawingTool
    @Binding var selectedColor: Color

    var body: some View {
        HStack(spacing: 12) {
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

            ColorPicker("Ink color", selection: $selectedColor, supportsOpacity: true)
                .labelsHidden()
                .accessibilityLabel("Ink color")
        }
        .padding(8)
        .toolbarBackground()
    }
}

// Shared toolbar appearance for the day and month drawing screens.
extension View {
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
