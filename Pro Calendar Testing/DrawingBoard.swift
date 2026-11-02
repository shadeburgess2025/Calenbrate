//
//  ContentView.swift
//  Pro Calendar Testing
//
//  Created by Shade Burgess on 10/25/26.
//

import SwiftUI
import PencilKit

enum DrawingTool: Hashable {
    case pen
    case eraser
    case lasso
}

struct DrawingBoard: UIViewControllerRepresentable {
    var selectedTool: DrawingTool
    var selectedColor: Color
    @Binding var drawing: PKDrawing

    func makeUIViewController(context: Context) -> DayPaperController {
        let controller = DayPaperController()
        controller.loadViewIfNeeded()
        controller.apply(drawing: drawing, tool: selectedTool, color: UIColor(selectedColor))
        controller.onDrawingChanged = { drawing = $0 }
        return controller
    }

    func updateUIViewController(_ controller: DayPaperController, context: Context) {
        controller.onDrawingChanged = { drawing = $0 }
        controller.apply(drawing: drawing, tool: selectedTool, color: UIColor(selectedColor))
    }

    static func dismantleUIViewController(_ controller: DayPaperController, coordinator: ()) {
        controller.onDrawingChanged = nil
    }
}

/// The canvas stays viewport-sized. PencilKit zooms the ink, while the paper
/// behind it follows the same scale and offset.
final class DayPaperController: UIViewController, PKCanvasViewDelegate {
    private let canvas = PKCanvasView()
    private let paper = RuledNotePaper()
    private let inkMask = CAShapeLayer()
    // Preserve the coordinate system used by existing day notes.
    private var pageSize = CGSize(width: 2200, height: 1600)
    private var previousViewport = CGSize.zero
    private var fitScale: CGFloat = 1
    private var updatingLayout = false
    private var applyingDrawing = false
    private var activeTool: DrawingTool?
    private var activeColor: UIColor?
    var onDrawingChanged: ((PKDrawing) -> Void)?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGray5
        view.clipsToBounds = true
        paper.bounds = CGRect(origin: .zero, size: pageSize)
        paper.isUserInteractionEnabled = false
        paper.layer.shadowColor = UIColor.black.cgColor
        paper.layer.shadowOpacity = 0.18
        paper.layer.shadowRadius = 12
        paper.layer.shadowOffset = CGSize(width: 0, height: 4)
        view.addSubview(paper)

        canvas.frame = view.bounds
        canvas.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        canvas.drawingPolicy = .pencilOnly
        canvas.contentSize = pageSize
        canvas.contentInsetAdjustmentBehavior = .never
        canvas.isScrollEnabled = true
        canvas.showsHorizontalScrollIndicator = false
        canvas.showsVerticalScrollIndicator = false
        canvas.panGestureRecognizer.minimumNumberOfTouches = 2
        let fingers = [NSNumber(value: UITouch.TouchType.direct.rawValue)]
        canvas.panGestureRecognizer.allowedTouchTypes = fingers
        canvas.pinchGestureRecognizer?.allowedTouchTypes = fingers
        canvas.delegate = self
        canvas.layer.mask = inkMask
        view.addSubview(canvas)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let viewport = canvas.bounds.size
        guard viewport.width > 0, viewport.height > 0 else { return }
        if viewport != previousViewport {
            let firstLayout = previousViewport == .zero
            let relativeZoom = firstLayout ? 1 : canvas.zoomScale / fitScale
            let center = CGPoint(
                x: (canvas.contentOffset.x + previousViewport.width / 2) / canvas.zoomScale,
                y: (canvas.contentOffset.y + previousViewport.height / 2) / canvas.zoomScale
            )
            previousViewport = viewport
            fitScale = min(max(1, viewport.width - 48) / pageSize.width,
                           max(1, viewport.height - 96) / pageSize.height)
            updatingLayout = true
            canvas.minimumZoomScale = fitScale * 0.65
            canvas.maximumZoomScale = max(4, fitScale * 4)
            canvas.setZoomScale(max(canvas.minimumZoomScale, min(canvas.maximumZoomScale, fitScale * relativeZoom)), animated: false)
            centerPaper()
            let proposed = firstLayout
                ? CGPoint(x: -canvas.contentInset.left, y: -canvas.contentInset.top)
                : CGPoint(x: center.x * canvas.zoomScale - viewport.width / 2,
                          y: center.y * canvas.zoomScale - viewport.height / 2)
            canvas.contentOffset = clampedOffset(proposed)
            updatingLayout = false
        }
        alignPaper()
    }

    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        guard !updatingLayout else { return }
        centerPaper()
        alignPaper()
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard !updatingLayout else { return }
        alignPaper()
    }

    private func centerPaper() {
        // Margins keep paper edges reachable even at high zoom. The bottom margin
        // also lets the last lines be moved clear of the floating toolbar.
        let horizontal = max(24, (canvas.bounds.width - pageSize.width * canvas.zoomScale) / 2)
        let vertical = max(24, (canvas.bounds.height - pageSize.height * canvas.zoomScale) / 2)
        let inset = UIEdgeInsets(top: vertical, left: horizontal, bottom: max(88, vertical), right: horizontal)
        if canvas.contentInset != inset { canvas.contentInset = inset }
    }

    private func clampedOffset(_ offset: CGPoint) -> CGPoint {
        let minX = -canvas.contentInset.left
        let minY = -canvas.contentInset.top
        let maxX = max(minX, pageSize.width * canvas.zoomScale - canvas.bounds.width + canvas.contentInset.right)
        let maxY = max(minY, pageSize.height * canvas.zoomScale - canvas.bounds.height + canvas.contentInset.bottom)
        return CGPoint(x: min(maxX, max(minX, offset.x)), y: min(maxY, max(minY, offset.y)))
    }

    private func alignPaper() {
        UIView.performWithoutAnimation {
            paper.transform = CGAffineTransform(scaleX: canvas.zoomScale, y: canvas.zoomScale)
            paper.center = CGPoint(x: pageSize.width * canvas.zoomScale / 2 - canvas.contentOffset.x,
                                   y: pageSize.height * canvas.zoomScale / 2 - canvas.contentOffset.y)
        }
        // Clip visible ink to the sheet rather than displaying it on the desk.
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        inkMask.frame = canvas.bounds
        inkMask.path = UIBezierPath(rect: paper.frame).cgPath
        CATransaction.commit()
    }

    func apply(drawing: PKDrawing, tool: DrawingTool, color: UIColor) {
        if canvas.drawing != drawing {
            applyingDrawing = true
            // Preserve old notes that extended beyond the original canvas size.
            if !drawing.strokes.isEmpty {
                let bounds = drawing.bounds
                if bounds.maxX.isFinite && bounds.maxY.isFinite {
                    let expanded = CGSize(width: max(pageSize.width, bounds.maxX + 40),
                                          height: max(pageSize.height, bounds.maxY + 40))
                    if expanded != pageSize {
                        pageSize = expanded
                        paper.bounds.size = expanded
                        canvas.contentSize = CGSize(width: expanded.width * canvas.zoomScale, height: expanded.height * canvas.zoomScale)
                        previousViewport = .zero
                        view.setNeedsLayout()
                    }
                }
            }
            canvas.drawing = drawing
            applyingDrawing = false
        }
        guard activeTool != tool || (tool == .pen && activeColor != color) else { return }
        activeTool = tool
        activeColor = color
        switch tool {
        case .pen: canvas.tool = PKInkingTool(.pen, color: color, width: 3)
        case .eraser: canvas.tool = PKEraserTool(.vector)
        case .lasso: canvas.tool = PKLassoTool()
        }
    }

    func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
        guard !applyingDrawing else { return }
        onDrawingChanged?(canvasView.drawing)
    }
}

/// Vector rules remain crisp when enlarged. They are decoration, not saved ink.
private final class RuledNotePaper: UIView {
    private let rules = CAShapeLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor(named: "DayNote")
        layer.addSublayer(rules)
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (paper: RuledNotePaper, _: UITraitCollection) in
            paper.setNeedsLayout()
        }
    }

    required init?(coder: NSCoder) { fatalError("Use init(frame:)") }

    override func layoutSubviews() {
        super.layoutSubviews()
        let path = UIBezierPath()
        rules.frame = bounds
        rules.path = path.cgPath
        rules.lineWidth = 1
        rules.strokeColor = UIColor.separator.withAlphaComponent(0.22).resolvedColor(with: traitCollection).cgColor
        rules.fillColor = nil
        layer.shadowPath = UIBezierPath(rect: bounds).cgPath
    }
}
