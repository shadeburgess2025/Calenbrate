//
//  ZoomableMonthBoard.swift
//  Calenbrate Testing
//
//  Created by Shade Burgess on 11/1/26.
//

import SwiftUI // views, controls, and state for the app interface
import PencilKit // apple pencil drawing tools and saved strokes

/// connects the month drawing controller to SwiftUI and lets PencilKit zoom the ink
struct ZoomableMonthBoard: UIViewControllerRepresentable {
    let month: Date
    // stores the original calendar dimensions and displayed month
    let pageSize: CGSize
    @Binding var drawing: PKDrawing
    // receives the selected drawing tool, color, width, and drawing binding
    var selectedTool: DrawingTool
    var selectedColor: Color
    var penWidth: CGFloat

    // makeUIViewController() function
    /// a controller returning function that creates the drawing board, applies the selected pen settings, then connects drawing changes to the parent view
    func makeUIViewController(context: Context) -> MonthCanvasController {
        let controller = MonthCanvasController(month: month, pageSize: pageSize)
        // creates the controller view before applying its drawing settings
        controller.loadViewIfNeeded()
        controller.apply(drawing: drawing, tool: selectedTool, color: UIColor(selectedColor), width: penWidth)
        // sends changed strokes back through the parent drawing binding
        controller.onDrawingChanged = { drawing = $0 }
        return controller
    }

    // updateUIViewController() function
    /// a void function that accepts the existing controller and updates its drawing, tool, color, and pen size
    func updateUIViewController(_ controller: MonthCanvasController, context: Context) {
        // sends changed strokes back through the parent drawing binding
        controller.onDrawingChanged = { drawing = $0 }
        controller.apply(drawing: drawing, tool: selectedTool, color: UIColor(selectedColor), width: penWidth)
    }

    // dismantleUIViewController() function
    /// a void function that removes the drawing callback when the controller is removed
    static func dismantleUIViewController(_ controller: MonthCanvasController, coordinator: ()) {
        controller.onDrawingChanged = nil
    }
}

/// handles month drawing gestures and keeps the calendar background aligned with the ink
final class MonthCanvasController: UIViewController, PKCanvasViewDelegate {
    // stores the original calendar dimensions and displayed month
    let pageSize: CGSize
    let month: Date
    let pageView = UIView()
    let canvas = PKCanvasView()
    private var calendarHost: UIHostingController<MonthCalendarLayout>?
    // declares the previous display size, zoom state, and tool settings
    private var previousViewport = CGSize.zero
    private var fitScale: CGFloat = 1
    private var applyingDrawing = false
    private var updatingViewport = false
    private var activeTool: DrawingTool?
    private var activeColor: UIColor?
    private var activeWidth: CGFloat?
    var onDrawingChanged: ((PKDrawing) -> Void)?

    // initializer
    /// accepts and stores the month and page dimensions before creating the controller
    init(month: Date, pageSize: CGSize) {
        self.month = month
        self.pageSize = pageSize
        super.init(nibName: nil, bundle: nil)
    }

    // initializer
    /// rejects storyboard initialization because this view is created in code
    required init?(coder: NSCoder) { fatalError("Use init(month:pageSize:)") }

    // viewDidLoad() function
    /// a void function that sets up the background and drawing canvas when the controller loads
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        view.clipsToBounds = true

        // creates the calendar background behind the canvas without changing PencilKit internal views
        pageView.bounds = CGRect(origin: .zero, size: pageSize)
        pageView.backgroundColor = .clear
        pageView.isUserInteractionEnabled = false
        view.addSubview(pageView)

        // places the SwiftUI calendar in a child controller with day navigation disabled
        let host = UIHostingController(rootView: MonthCalendarLayout(month: month, allowsDayNavigation: false))
        host.safeAreaRegions = []
        addChild(host)
        host.view.frame = pageView.bounds
        host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        host.view.backgroundColor = .clear
        host.view.isUserInteractionEnabled = false
        pageView.addSubview(host.view)
        host.didMove(toParent: self)
        calendarHost = host

        // sizes the canvas to the visible area and keeps its background transparent
        canvas.frame = view.bounds
        canvas.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        canvas.drawingPolicy = .pencilOnly
        canvas.contentSize = pageSize
        canvas.contentInsetAdjustmentBehavior = .never
        canvas.isScrollEnabled = true
        canvas.minimumZoomScale = 1
        canvas.maximumZoomScale = 4
        canvas.bouncesZoom = false
        canvas.bounces = false
        canvas.showsHorizontalScrollIndicator = false
        canvas.showsVerticalScrollIndicator = false
        // requires two fingers for panning and reserves the pencil for drawing
        canvas.panGestureRecognizer.minimumNumberOfTouches = 2
        canvas.panGestureRecognizer.allowedTouchTypes = [NSNumber(value: UITouch.TouchType.direct.rawValue)]
        canvas.pinchGestureRecognizer?.allowedTouchTypes = [NSNumber(value: UITouch.TouchType.direct.rawValue)]
        canvas.delegate = self
        view.addSubview(canvas)
    }

    // viewDidLayoutSubviews() function
    /// a void function that checks the available size, updates the zoom limits, then positions the page and drawing
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // gets the available drawing area before calculating zoom and centering
        let viewport = canvas.bounds.size
        guard viewport.width > 0, viewport.height > 0, viewport != previousViewport else { return }
        let firstLayout = previousViewport == .zero
        // keeps the current magnification relative to the fitted page size
        let relativeZoom = firstLayout ? 1 : canvas.zoomScale / fitScale
        // stores the viewed page center before changing the available size
        let oldCenter = CGPoint(
            x: (canvas.contentOffset.x + previousViewport.width / 2) / canvas.zoomScale,
            y: (canvas.contentOffset.y + previousViewport.height / 2) / canvas.zoomScale
        )
        previousViewport = viewport
        // calculates the scale needed to fit the page into the available area
        fitScale = min(viewport.width / pageSize.width, viewport.height / pageSize.height)
        updatingViewport = true
        // sets the zoom limits relative to the fitted page size
        canvas.minimumZoomScale = fitScale
        canvas.maximumZoomScale = fitScale * 4
        canvas.setZoomScale(fitScale * min(4, max(1, relativeZoom)), animated: false)
        updateCenteringInsets()
        // calculates the starting scroll position or preserves the previously viewed page center
        let proposed = firstLayout
            ? CGPoint(x: -canvas.contentInset.left, y: -canvas.contentInset.top)
            : CGPoint(x: oldCenter.x * canvas.zoomScale - viewport.width / 2,
                      y: oldCenter.y * canvas.zoomScale - viewport.height / 2)
        // calculates the scroll limits including the centering margins
        let minimum = CGPoint(x: -canvas.contentInset.left, y: -canvas.contentInset.top)
        let maximum = CGPoint(
            x: max(minimum.x, pageSize.width * canvas.zoomScale - viewport.width + canvas.contentInset.right),
            y: max(minimum.y, pageSize.height * canvas.zoomScale - viewport.height + canvas.contentInset.bottom)
        )
        // keeps the new scroll position within the page limits
        canvas.contentOffset = CGPoint(
            x: min(maximum.x, max(minimum.x, proposed.x)),
            y: min(maximum.y, max(minimum.y, proposed.y))
        )
        updatingViewport = false
        alignCalendar()
    }

    // scrollViewDidZoom() function
    /// a void function that updates the background position and margins when the user zooms the drawing
    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        guard !updatingViewport else { return }
        updateCenteringInsets()
        alignCalendar()
    }

    // scrollViewDidScroll() function
    /// a void function that moves the background with the drawing when the user pans
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard !updatingViewport else { return }
        alignCalendar()
    }

    // updateCenteringInsets() function
    /// a void function that calculates equal margins to center the calendar when it is smaller than the available area
    private func updateCenteringInsets() {
        // calculates equal margins to center pages smaller than the screen
        let horizontal = max(0, (canvas.bounds.width - pageSize.width * canvas.zoomScale) / 2)
        let vertical = max(0, (canvas.bounds.height - pageSize.height * canvas.zoomScale) / 2)
        let inset = UIEdgeInsets(top: vertical, left: horizontal, bottom: vertical, right: horizontal)
        if canvas.contentInset != inset { canvas.contentInset = inset }
    }

    // alignCalendar() function
    /// a void function that matches the calendar background to the canvas zoom and scroll position
    private func alignCalendar() {
        // matches the calendar to the ink using the canvas offset, which already includes centering margins
        UIView.performWithoutAnimation {
            pageView.transform = CGAffineTransform(scaleX: canvas.zoomScale, y: canvas.zoomScale)
            pageView.center = CGPoint(
                x: pageSize.width * canvas.zoomScale / 2 - canvas.contentOffset.x,
                y: pageSize.height * canvas.zoomScale / 2 - canvas.contentOffset.y
            )
        }
    }

    // apply() function
    /// a void function that accepts a drawing and tool settings, loads changed drawing data, then updates the selected tool if necessary
    func apply(drawing: PKDrawing, tool: DrawingTool, color: UIColor, width: CGFloat) {
        // loads changed drawing data without reporting it as a new user edit
        if canvas.drawing != drawing {
            applyingDrawing = true
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
        case .pen:
            canvas.tool = PKInkingTool(.pen, color: color, width: width)
        case .eraser:
            // uses the smallest supported eraser width while removing whole strokes
            canvas.tool = PKEraserTool(
                .vector,
                width: PKEraserTool.EraserType.vector.validWidthRange.lowerBound
            )
        case .lasso:
            canvas.tool = PKLassoTool()
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
