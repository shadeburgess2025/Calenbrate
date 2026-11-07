//
//  CalendarView.swift
//  Calenbrate Testing
//
//  Created by Shade Burgess on 10/24/26.
//

import SwiftUI // views, controls, and state for the app interface
import SwiftData // stores and loads saved notes

extension View {
    // calendarGlass() function
    /// a view returning function that accepts the paging state and applies glass on supported iOS versions
    @ViewBuilder
    func calendarGlass(isPaging: Bool) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(
                .regular,
                in: RoundedRectangle(cornerRadius: 20)
            )
        } else {
            self
        }
    }

    // gridBox() function
    /// a view returning function that accepts the highlight state and draws the border for a calendar cell
    @ViewBuilder
    func gridBox(isTinted: Bool) -> some View {
        self.overlay {
            RoundedRectangle(cornerRadius: 5)
                .strokeBorder(
                    isTinted
                        ? Color.blue
                        : Color.primary.opacity(0.15),
                    lineWidth: isTinted ? 1.5 : 0.5
                )
        }
    }
}

/// displays the previous, current, and next month and handles swiping between them
struct CalendarView: View {
    // declares the displayed month, drag position, scale, and paging state variables
    @State private var currentMonth = Date()
    @State private var dragOffset: CGFloat = 0
    @State private var calendarScale: CGFloat = 1
    @State private var isAnimating = false
    @State private var isPaging = false
    @State private var isEditingMonth = false
    // uses the Gregorian calendar for month calculations
    let cal = Calendar(identifier: .gregorian)

    var body: some View {
        // gets the safe area margins before allowing the pages to fill the screen
        GeometryReader { safeGeometry in
            let contentInsets = safeGeometry.safeAreaInsets

            GeometryReader { geometry in
                // stores the full page height used for positioning and swipe distance
                let h = geometry.size.height

                ZStack {
                    // displays the previous month above the current page
                    calendarBody(for: month(by: -1), contentInsets: contentInsets)
                        .frame(width: geometry.size.width, height: h)
                        .calendarGlass(isPaging: isPaging)
                        .scaleEffect(calendarScale)
                        .geometryGroup()
                        .offset(y: -h + dragOffset)

                    // displays the current month at the current drag position
                    calendarBody(for: currentMonth, contentInsets: contentInsets)
                        .frame(width: geometry.size.width, height: h)
                        .calendarGlass(isPaging: isPaging)
                        .scaleEffect(calendarScale)
                        .geometryGroup()
                        .offset(y: dragOffset)

                    // displays the next month below the current page
                    calendarBody(for: month(by: 1), contentInsets: contentInsets)
                        .frame(width: geometry.size.width, height: h)
                        .calendarGlass(isPaging: isPaging)
                        .scaleEffect(calendarScale)
                        .geometryGroup()
                        .offset(y: h + dragOffset)
                }
                .frame(width: geometry.size.width, height: h)
                // hides neighboring pages outside the paging area
                .clipped()
                .contentShape(Rectangle())
                // handles month swipes before day cell taps
                .highPriorityGesture(
                    DragGesture(minimumDistance: 10)
                        // updates the drag position and shrinks the page while swiping
                        .onChanged { value in
                            if !isAnimating && !isEditingMonth {
                                isPaging = true
                                dragOffset = value.translation.height
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    calendarScale = 0.92
                                }
                            }
                        }
                        // finishes the swipe when the user releases their finger
                        .onEnded { value in
                            if !isAnimating && !isEditingMonth {
                                finishSwipe(
                                    distance: value.translation.height,
                                    velocity: value.velocity.height,
                                    height: h
                                )
                            }
                        },
                    // allows drawing gestures instead of month swipes while editing
                    including: isEditingMonth ? .subviews : .all
                )
            }
            .ignoresSafeArea(.container, edges: .vertical)
            .background {
                Color("MonthBackground")
                    .ignoresSafeArea()
            }
        }
    }

    // finishSwipe() function
    /// a void function that accepts drag distance, speed, and page height, chooses the next month, then resets the swipe state
    @MainActor
    func finishSwipe(distance: CGFloat, velocity: CGFloat, height: CGFloat) {
        // stops if an animation is already running or the height is invalid
        guard !isAnimating, height > 0 else { return }

        // declares the distance and speed required to switch months
        let pos_threshold: CGFloat = 150
        let vel_threshold: CGFloat = 500
        let direction: Int

        // chooses the next month for an upward swipe, previous month for a downward swipe, or stays on the same month
        if distance < -pos_threshold || velocity < -vel_threshold {
            direction = 1
        } else if distance > pos_threshold || velocity > vel_threshold {
            direction = -1
        } else {
            direction = 0
        }

        // resets the scale without changing months if the page has not moved
        guard direction != 0 || dragOffset != 0 else {
            // animates the page back to its full size
            withAnimation(.easeOut(duration: 0.25)) {
                calendarScale = 1
                isPaging = false
            }
            return
        }

        // calculates the destination month and final page offset before animating
        let destinationMonth = month(by: direction)
        let targetOffset: CGFloat = direction == 0
            ? 0
            : -CGFloat(direction) * height

        // prevents another swipe from starting during the transition
        isAnimating = true

        // animates the page back to its full size
        withAnimation(.easeOut(duration: 0.25)) {
            dragOffset = targetOffset
            calendarScale = 1
        }

        // waits for the transition to finish without blocking the interface
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(275))

            // disables animation while resetting the three page positions
            var transaction = Transaction(animation: nil)
            transaction.disablesAnimations = true

            // sets the displayed month, clears the drag offset, and allows swiping again
            withTransaction(transaction) {
                currentMonth = destinationMonth
                dragOffset = 0
                isAnimating = false
                isPaging = false
            }
        }
    }

    // month() function
    /// a date returning function that accepts a month offset and returns that month relative to the current month
    func month(by amount: Int) -> Date {
        cal.date(
            byAdding: .month,
            value: amount,
            to: cal.dateInterval(of: .month, for: currentMonth)?.start ?? currentMonth
        ) ?? currentMonth
    }

    // calendarBody() function
    /// a view returning function that accepts a month and screen margins, then displays the month inside those margins
    func calendarBody(for month: Date, contentInsets: EdgeInsets) -> some View {
        GeometryReader { geometry in
            // subtracts the top and bottom margins and prevents a zero or negative content height
            let contentHeight = max(
                1,
                geometry.size.height - contentInsets.top - contentInsets.bottom
            )

            MonthPage(
                month: month,
                viewportSize: CGSize(width: geometry.size.width, height: contentHeight),
                isEditing: $isEditingMonth,
                canEdit: !isPaging && !isAnimating && cal.isDate(month, equalTo: currentMonth, toGranularity: .month)
            )
            .id(MonthIdentity.key(for: month))
            .frame(width: geometry.size.width, height: contentHeight)
            .padding(.top, contentInsets.top)
            .padding(.bottom, contentInsets.bottom)
        }
    }
}

// displays a preview using temporary storage when a model container is provided
#Preview {
    NavigationStack { CalendarView() }
        .modelContainer(for: [DayNote.self, MonthNote.self], inMemory: true)
}
