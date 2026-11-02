//
//  ContentView.swift
//  Pro Calendar Testing
//
//  Created by Shade Burgess on 11/1/26.
//

import SwiftUI

/// The same fixed-size layout is used beneath saved ink and inside the editor.
struct MonthCalendarLayout: View {
    let month: Date
    var allowsDayNavigation = true

    private let calendar = Calendar(identifier: .gregorian)

    var body: some View {
        let first = calendar.dateInterval(of: .month, for: month)?.start ?? month
        let leadingDays = calendar.component(.weekday, from: first) - 1
        let days = calendar.range(of: .day, in: .month, for: first)?.count ?? 31
        let rows = max(5, (leadingDays + days + 6) / 7)

        VStack(spacing: 8) {
            ZStack {
                HStack {
                    Spacer()
                    Text(month.formatted(.dateTime.year()))
                        .font(.title2)
                        .padding(.trailing, 20)
                }
                Text(month.formatted(.dateTime.month(.wide)))
                    .font(.largeTitle.bold())
            }

            HStack(spacing: 5) {
                ForEach(["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"], id: \.self) { day in
                    Text(day)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 20)

            GeometryReader { geometry in
                let cellHeight = max(0, (geometry.size.height - CGFloat(rows - 1) * 5) / CGFloat(rows))
                // All cells must exist when the layout is hosted in the zoomable editor.
                VStack(spacing: 5) {
                    ForEach(0..<rows, id: \.self) { row in
                        HStack(spacing: 5) {
                            ForEach(0..<7, id: \.self) { column in
                                let index = row * 7 + column
                                let date = calendar.date(byAdding: .day, value: index - leadingDays, to: first) ?? first
                                let inMonth = index >= leadingDays && index < leadingDays + days
                                if inMonth && allowsDayNavigation {
                                    NavigationLink {
                                        DayView(date: date)
                                    } label: {
                                        cell(date: date, inMonth: true, height: cellHeight)
                                    }
                                    .buttonStyle(.plain)
                                } else {
                                    cell(date: date, inMonth: inMonth, height: cellHeight)
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        // Keep calendar geometry stable even when the system text size changes.
        .dynamicTypeSize(.large)
    }

    private func cell(date: Date, inMonth: Bool, height: CGFloat) -> some View {
        Text("\(calendar.component(.day, from: date))")
            .padding(5)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            .frame(height: height)
            .gridBox(isTinted: inMonth && calendar.isDateInToday(date))
            .opacity(inMonth ? 1 : 0.3)
            .contentShape(Rectangle())
    }
}
