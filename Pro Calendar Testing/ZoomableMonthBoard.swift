//
//  ContentView.swift
//  Pro Calendar Testing
//
//  Created by Shade Burgess on 11/1/26.
//

import SwiftUI
import PencilKit

/// PencilKit owns zooming, so ink is rendered at the actual zoom resolution.
struct ZoomableMonthBoard: UIViewControllerRepresentable {
    let month: Date
    let pageSize: CGSize
    @Binding var drawing: PKDrawing
    var selectedTool: DrawingTool
    var selectedColor: Color

    func makeUIViewController(context: Context) -> MonthCanvasController {
        let controller = MonthCanvasController(month: month, pageSize: pageSize)
        controller.loadViewIfNeeded()
        controller.apply(drawing: drawing, tool: selectedTool, color: UIColor(selectedColor))
        controller.onDrawingChanged = { drawing = $0 }
        return controller
    }

    func updateUIViewController(_ controller: MonthCanvasController, context: Context) {
        controller.onDrawingChanged = { drawing = $0 }
        controller.apply(drawing: drawing, tool: selectedTool, color: UIColor(selectedColor))
    }

    static func dismantleUIViewController(_ controller: MonthCanvasController, coordinator: ()) {
        controller.onDrawingChanged = nil
    }
}

final class MonthCanvasController: UIViewController, PKCanvasViewDelegate {
    let pageSize: CGSize
    let month: Date
    let pageView = UIView()
    let canvas = PKCanvasView()
    private var calendarHost: UIHostingController<MonthCalendarLayout>?
    private var previousViewport = CGSize.zero
    private var fitScale: CGFloat = 1
    private var applyingDrawing = false
    private var updatingViewport = false
    private var activeTool: DrawingTool?
    private var activeColor: UIColor?
    var onDrawingChanged: ((PKDrawing) -> Void)?

    init(month: Date, pageSize: CGSize) {
        self.month = month
        self.pageSize = pageSize
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("Use init(month:pageSize:)") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        view.clipsToBounds = true

        // This is a sibling behind the canvas, not part of PencilKit's internal views.
        pageView.bounds = CGRect(origin: .zero, size: pageSize)
        pageView.backgroundColor = .clear
        pageView.isUserInteractionEnabled = false
        view.addSubview(pageView)

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
        canvas.panGestureRecognizer.minimumNumberOfTouches = 2
        canvas.panGestureRecognizer.allowedTouchTypes = [NSNumber(value: UITouch.TouchType.direct.rawValue)]
        canvas.pinchGestureRecognizer?.allowedTouchTypes = [NSNumber(value: UITouch.TouchType.direct.rawValue)]
        canvas.delegate = self
        view.addSubview(canvas)
        // Do not implement viewForZooming: PencilKit manages its own ink surface.
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let viewport = canvas.bounds.size
        guard viewport.width > 0, viewport.height > 0, viewport != previousViewport else { return }
        let firstLayout = previousViewport == .zero
        let relativeZoom = firstLayout ? 1 : canvas.zoomScale / fitScale
        let oldCenter = CGPoint(
            x: (canvas.contentOffset.x + previousViewport.width / 2) / canvas.zoomScale,
            y: (canvas.contentOffset.y + previousViewport.height / 2) / canvas.zoomScale
        )
        previousViewport = viewport
        fitScale = min(viewport.width / pageSize.width, viewport.height / pageSize.height)
        updatingViewport = true
        canvas.minimumZoomScale = fitScale
        canvas.maximumZoomScale = fitScale * 4
        canvas.setZoomScale(fitScale * min(4, max(1, relativeZoom)), animated: false)
        updateCenteringInsets()
        let proposed = firstLayout
            ? CGPoint(x: -canvas.contentInset.left, y: -canvas.contentInset.top)
            : CGPoint(x: oldCenter.x * canvas.zoomScale - viewport.width / 2,
                      y: oldCenter.y * canvas.zoomScale - viewport.height / 2)
        let minimum = CGPoint(x: -canvas.contentInset.left, y: -canvas.contentInset.top)
        let maximum = CGPoint(
            x: max(minimum.x, pageSize.width * canvas.zoomScale - viewport.width + canvas.contentInset.right),
            y: max(minimum.y, pageSize.height * canvas.zoomScale - viewport.height + canvas.contentInset.bottom)
        )
        canvas.contentOffset = CGPoint(
            x: min(maximum.x, max(minimum.x, proposed.x)),
            y: min(maximum.y, max(minimum.y, proposed.y))
        )
        updatingViewport = false
        alignCalendar()
    }

    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        guard !updatingViewport else { return }
        updateCenteringInsets()
        alignCalendar()
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard !updatingViewport else { return }
        alignCalendar()
    }

    private func updateCenteringInsets() {
        let horizontal = max(0, (canvas.bounds.width - pageSize.width * canvas.zoomScale) / 2)
        let vertical = max(0, (canvas.bounds.height - pageSize.height * canvas.zoomScale) / 2)
        let inset = UIEdgeInsets(top: vertical, left: horizontal, bottom: vertical, right: horizontal)
        if canvas.contentInset != inset { canvas.contentInset = inset }
    }

    private func alignCalendar() {
        // contentOffset already includes the negative offset introduced by centering
        // insets. Adding those insets again would shift the calendar away from the ink.
        UIView.performWithoutAnimation {
            pageView.transform = CGAffineTransform(scaleX: canvas.zoomScale, y: canvas.zoomScale)
            pageView.center = CGPoint(
                x: pageSize.width * canvas.zoomScale / 2 - canvas.contentOffset.x,
                y: pageSize.height * canvas.zoomScale / 2 - canvas.contentOffset.y
            )
        }
    }

    func apply(drawing: PKDrawing, tool: DrawingTool, color: UIColor) {
        if canvas.drawing != drawing {
            applyingDrawing = true
            canvas.drawing = drawing
            applyingDrawing = false
        }
        // Color changes must update the pen even when its tool type stays the same.
        guard activeTool != tool || (tool == .pen && activeColor != color) else { return }
        activeTool = tool
        activeColor = color
        switch tool {
        case .pen:
            canvas.tool = PKInkingTool(.pen, color: color, width: 3)
        case .eraser:
            canvas.tool = PKEraserTool(.vector)
        case .lasso:
            canvas.tool = PKLassoTool()
        }
    }

    func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
        guard !applyingDrawing else { return }
        onDrawingChanged?(canvasView.drawing)
    }
}
