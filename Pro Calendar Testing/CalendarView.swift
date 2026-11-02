//
//  CalendarView.swift
//  Pro Calendar Testing
//
//  Created by Shade Burgess on 10/24/26.
//

import SwiftUI
import SwiftData

extension View {
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

struct CalendarView: View {
    @State private var currentMonth = Date()
    @State private var dragOffset: CGFloat = 0
    @State private var calendarScale: CGFloat = 1
    @State private var isAnimating = false
    @State private var isPaging = false
    @State private var isEditingMonth = false
    let cal = Calendar(identifier: .gregorian)

    var body: some View {
        // Capture the protected content margins before expanding the paging viewport.
        GeometryReader { safeGeometry in
            let contentInsets = safeGeometry.safeAreaInsets

            GeometryReader { geometry in
                let h = geometry.size.height

                ZStack {
                    calendarBody(for: month(by: -1), contentInsets: contentInsets)
                        .frame(width: geometry.size.width, height: h)
                        .calendarGlass(isPaging: isPaging)
                        .scaleEffect(calendarScale)
                        .geometryGroup()
                        .offset(y: -h + dragOffset)

                    calendarBody(for: currentMonth, contentInsets: contentInsets)
                        .frame(width: geometry.size.width, height: h)
                        .calendarGlass(isPaging: isPaging)
                        .scaleEffect(calendarScale)
                        .geometryGroup()
                        .offset(y: dragOffset)

                    calendarBody(for: month(by: 1), contentInsets: contentInsets)
                        .frame(width: geometry.size.width, height: h)
                        .calendarGlass(isPaging: isPaging)
                        .scaleEffect(calendarScale)
                        .geometryGroup()
                        .offset(y: h + dragOffset)
                }
                .frame(width: geometry.size.width, height: h)
                .clipped()
                .contentShape(Rectangle())
                .highPriorityGesture(
                    DragGesture(minimumDistance: 10)
                        .onChanged { value in
                            if !isAnimating && !isEditingMonth {
                                isPaging = true
                                dragOffset = value.translation.height
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    calendarScale = 0.92
                                }
                            }
                        }
                        .onEnded { value in
                            if !isAnimating && !isEditingMonth {
                                finishSwipe(
                                    distance: value.translation.height,
                                    velocity: value.velocity.height,
                                    height: h
                                )
                            }
                        },
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

    @MainActor
    func finishSwipe(distance: CGFloat, velocity: CGFloat, height: CGFloat) {
        guard !isAnimating, height > 0 else { return }

        let pos_threshold: CGFloat = 150
        let vel_threshold: CGFloat = 500
        let direction: Int

        if distance < -pos_threshold || velocity < -vel_threshold {
            direction = 1
        } else if distance > pos_threshold || velocity > vel_threshold {
            direction = -1
        } else {
            direction = 0
        }

        guard direction != 0 || dragOffset != 0 else {
            withAnimation(.easeOut(duration: 0.25)) {
                calendarScale = 1
                isPaging = false
            }
            return
        }

        // Capture the destination before starting the animation.
        let destinationMonth = month(by: direction)
        let targetOffset: CGFloat = direction == 0
            ? 0
            : -CGFloat(direction) * height

        isAnimating = true

        withAnimation(.easeOut(duration: 0.25)) {
            dragOffset = targetOffset
            calendarScale = 1
        }

        Task { @MainActor in
            // Wait slightly longer than the animation.
            // This suspends the task without blocking the interface.
            try? await Task.sleep(for: .milliseconds(275))

            var transaction = Transaction(animation: nil)
            transaction.disablesAnimations = true

            withTransaction(transaction) {
                currentMonth = destinationMonth
                dragOffset = 0
                isAnimating = false
                isPaging = false
            }
        }
    }

    func month(by amount: Int) -> Date {
        cal.date(
            byAdding: .month,
            value: amount,
            to: cal.dateInterval(of: .month, for: currentMonth)?.start ?? currentMonth
        ) ?? currentMonth
    }

    func calendarBody(for month: Date, contentInsets: EdgeInsets) -> some View {
        GeometryReader { geometry in
            // All three pages use the same content area. Saved drawings retain
            // their own coordinate system inside it.
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

#Preview {
    NavigationStack { CalendarView() }
        .modelContainer(for: [DayNote.self, MonthNote.self], inMemory: true)
}
