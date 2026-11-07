//
//  DrawingBoard.swift
//  Calenbrate Testing
//
//  Created by Shade Burgess on 10/25/26.
//

import SwiftUI // views, controls, and state for the app interface
import PencilKit // apple pencil drawing tools and saved strokes

/// declares the drawing tools that can be selected from the toolbar
enum DrawingTool: Hashable {
    case pen
    case eraser
    case lasso
}

/// connects the day drawing controller to SwiftUI and passes in the selected tool settings
struct DrawingBoard: UIViewControllerRepresentable {
    // receives the selected drawing tool, color, width, and drawing binding
    var selectedTool: DrawingTool
    var selectedColor: Color
    var penWidth: CGFloat
    @Binding var drawing: PKDrawing

    // makeUIViewController() function
    /// a controller returning function that creates the drawing board, applies the selected pen settings, then connects drawing changes to the parent view
    func makeUIViewController(context: Context) -> DayPaperController {
        let controller = DayPaperController()
        // creates the controller view before applying its drawing settings
        controller.loadViewIfNeeded()
        controller.apply(drawing: drawing, tool: selectedTool, color: UIColor(selectedColor), width: penWidth)
        // sends changed strokes back through the parent drawing binding
        controller.onDrawingChanged = { drawing = $0 }
        return controller
    }

    // updateUIViewController() function
    /// a void function that accepts the existing controller and updates its drawing, tool, color, and pen size
    func updateUIViewController(_ controller: DayPaperController, context: Context) {
        // sends changed strokes back through the parent drawing binding
        controller.onDrawingChanged = { drawing = $0 }
        controller.apply(drawing: drawing, tool: selectedTool, color: UIColor(selectedColor), width: penWidth)
    }

    // dismantleUIViewController() function
    /// a void function that removes the drawing callback when the controller is removed
    static func dismantleUIViewController(_ controller: DayPaperController, coordinator: ()) {
        controller.onDrawingChanged = nil
    }
}

/// handles drawing, scrolling, and zooming while keeping the paper aligned with the ink
final class DayPaperController: UIViewController, PKCanvasViewDelegate {
    // creates the drawing canvas and paper display objects
    private let canvas = PKCanvasView()
    private let paper = RuledNotePaper()
    private let inkMask = CAShapeLayer()
    // uses the original day note dimensions to keep existing strokes in the same positions
    private var pageSize = CGSize(width: 2200, height: 1600)
    // declares the previous display size, zoom state, and tool settings
    private var previousViewport = CGSize.zero
    private var fitScale: CGFloat = 1
    private var updatingLayout = false
    private var applyingDrawing = false
    private var activeTool: DrawingTool?
    private var activeColor: UIColor?
    private var activeWidth: CGFloat?
    var onDrawingChanged: ((PKDrawing) -> Void)?

    // viewDidLoad() function
    /// a void function that sets up the background and drawing canvas when the controller loads
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGray5
        view.clipsToBounds = true
        // sets the paper size and adds a shadow to separate it from the workspace
        paper.bounds = CGRect(origin: .zero, size: pageSize)
        paper.isUserInteractionEnabled = false
        paper.layer.shadowColor = UIColor.black.cgColor
        paper.layer.shadowOpacity = 0.18
        paper.layer.shadowRadius = 12
        paper.layer.shadowOffset = CGSize(width: 0, height: 4)
        view.addSubview(paper)

        // sizes the canvas to the visible area and keeps its background transparent
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
        // requires two fingers for panning and reserves the pencil for drawing
        canvas.panGestureRecognizer.minimumNumberOfTouches = 2
        let fingers = [NSNumber(value: UITouch.TouchType.direct.rawValue)]
        canvas.panGestureRecognizer.allowedTouchTypes = fingers
        canvas.pinchGestureRecognizer?.allowedTouchTypes = fingers
        canvas.delegate = self
        canvas.layer.mask = inkMask
        view.addSubview(canvas)
    }

    // viewDidLayoutSubviews() function
    /// a void function that checks the available size, updates the zoom limits, then positions the page and drawing
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // gets the available drawing area before calculating zoom and centering
        let viewport = canvas.bounds.size
        guard viewport.width > 0, viewport.height > 0 else { return }
        if viewport != previousViewport {
            let firstLayout = previousViewport == .zero
            // keeps the current magnification relative to the fitted page size
            let relativeZoom = firstLayout ? 1 : canvas.zoomScale / fitScale
            let center = CGPoint(
                x: (canvas.contentOffset.x + previousViewport.width / 2) / canvas.zoomScale,
                y: (canvas.contentOffset.y + previousViewport.height / 2) / canvas.zoomScale
            )
            previousViewport = viewport
            // calculates the scale needed to fit the page into the available area
            fitScale = min(max(1, viewport.width - 48) / pageSize.width,
                           max(1, viewport.height - 96) / pageSize.height)
            updatingLayout = true
            // sets the zoom limits relative to the fitted page size
            canvas.minimumZoomScale = fitScale * 0.65
            canvas.maximumZoomScale = max(4, fitScale * 4)
            canvas.setZoomScale(max(canvas.minimumZoomScale, min(canvas.maximumZoomScale, fitScale * relativeZoom)), animated: false)
            centerPaper()
            // calculates the starting scroll position or preserves the previously viewed page center
            let proposed = firstLayout
                ? CGPoint(x: -canvas.contentInset.left, y: -canvas.contentInset.top)
                : CGPoint(x: center.x * canvas.zoomScale - viewport.width / 2,
                          y: center.y * canvas.zoomScale - viewport.height / 2)
            canvas.contentOffset = clampedOffset(proposed)
            updatingLayout = false
        }
        alignPaper()
    }

    // scrollViewDidZoom() function
    /// a void function that updates the background position and margins when the user zooms the drawing
    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        guard !updatingLayout else { return }
        centerPaper()
        alignPaper()
    }

    // scrollViewDidScroll() function
    /// a void function that moves the background with the drawing when the user pans
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard !updatingLayout else { return }
        alignPaper()
    }

    // centerPaper() function
    /// a void function that calculates paper margins and leaves room to move the bottom of the page above the toolbar
    private func centerPaper() {
        // calculates side and top margins, leaving extra space below the paper for the toolbar
        let horizontal = max(24, (canvas.bounds.width - pageSize.width * canvas.zoomScale) / 2)
        let vertical = max(24, (canvas.bounds.height - pageSize.height * canvas.zoomScale) / 2)
        let inset = UIEdgeInsets(top: vertical, left: horizontal, bottom: max(88, vertical), right: horizontal)
        if canvas.contentInset != inset { canvas.contentInset = inset }
    }

    // clampedOffset() function
    /// a point returning function that accepts a proposed scroll position and limits it to the page and its margins
    private func clampedOffset(_ offset: CGPoint) -> CGPoint {
        // calculates the minimum and maximum allowed scroll positions
        let minX = -canvas.contentInset.left
        let minY = -canvas.contentInset.top
        let maxX = max(minX, pageSize.width * canvas.zoomScale - canvas.bounds.width + canvas.contentInset.right)
        let maxY = max(minY, pageSize.height * canvas.zoomScale - canvas.bounds.height + canvas.contentInset.bottom)
        return CGPoint(x: min(maxX, max(minX, offset.x)), y: min(maxY, max(minY, offset.y)))
    }

    // alignPaper() function
    /// a void function that matches the paper to the drawing scale and position, then limits visible ink to the paper
    private func alignPaper() {
        // moves and scales the paper to match the ink without a separate animation
        UIView.performWithoutAnimation {
            paper.transform = CGAffineTransform(scaleX: canvas.zoomScale, y: canvas.zoomScale)
            paper.center = CGPoint(x: pageSize.width * canvas.zoomScale / 2 - canvas.contentOffset.x,
                                   y: pageSize.height * canvas.zoomScale / 2 - canvas.contentOffset.y)
        }
        // updates the ink mask without animation so strokes are only visible over the paper
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        inkMask.frame = canvas.bounds
        inkMask.path = UIBezierPath(rect: paper.frame).cgPath
        CATransaction.commit()
    }

    // apply() function
    /// a void function that accepts a drawing and tool settings, loads changed drawing data, then updates the selected tool if necessary
    func apply(drawing: PKDrawing, tool: DrawingTool, color: UIColor, width: CGFloat) {
        // loads changed drawings without sending the load back as a user drawing change
        if canvas.drawing != drawing {
            applyingDrawing = true
            // expands the paper if an older drawing extends past the original page dimensions
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
        // checks whether the selected tool, pen color, or pen width changed
        let toolChanged = activeTool != tool
        let penSettingsChanged = tool == .pen
            && (activeColor != color || activeWidth != width)
        // skips recreating the tool when none of its settings changed
        guard toolChanged || penSettingsChanged else { return }
        // stores the applied tool settings for the next update
        activeTool = tool
        activeColor = color
        activeWidth = width
        // sets the selected drawing tool using the current pen color and width
        switch tool {
        case .pen: canvas.tool = PKInkingTool(.pen, color: color, width: width)
        case .eraser: canvas.tool = PKEraserTool(.vector)
        case .lasso: canvas.tool = PKLassoTool()
        }
    }

    // canvasViewDrawingDidChange() function
    /// a void function that sends changed strokes from the canvas back to the parent view
    func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
        // ignores canvas notifications caused by loading a drawing from the parent view
        guard !applyingDrawing else { return }
        onDrawingChanged?(canvasView.drawing)
    }
}

/// displays the note paper background and its shadow
private final class RuledNotePaper: UIView {
    private let rules = CAShapeLayer()

    // initializer
    /// accepts the frame, then sets up the paper color and appearance updates
    override init(frame: CGRect) {
        super.init(frame: frame)
        // sets the paper color from the light and dark appearance asset
        backgroundColor = UIColor(named: "DayNote")
        layer.addSublayer(rules)
        // updates the paper decoration when the light or dark appearance changes
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (paper: RuledNotePaper, _: UITraitCollection) in
            paper.setNeedsLayout()
        }
    }

    // initializer
    /// rejects storyboard initialization because this view is created in code
    required init?(coder: NSCoder) { fatalError("Use init(frame:)") }

    // layoutSubviews() function
    /// a void function that updates the paper decoration and shadow to match the current paper bounds
    override func layoutSubviews() {
        super.layoutSubviews()
        // creates an empty decoration path so no ruled lines are drawn
        let path = UIBezierPath()
        rules.frame = bounds
        rules.path = path.cgPath
        rules.lineWidth = 1
        rules.strokeColor = UIColor.separator.withAlphaComponent(0.22).resolvedColor(with: traitCollection).cgColor
        rules.fillColor = nil
        // matches the paper shadow to the current paper bounds
        layer.shadowPath = UIBezierPath(rect: bounds).cgPath
    }
}
