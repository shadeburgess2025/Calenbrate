//
//  MonthCalendarLayout.swift
//  Calenbrate Testing
//
//  Created by Shade Burgess on 11/1/26.
//

import SwiftUI // views, controls, and state for the app interface

/// displays the month header, weekdays, and day cells for browsing and editing
struct MonthCalendarLayout: View {
    let month: Date
    var allowsDayNavigation = true

    private let calendar = Calendar(identifier: .gregorian)

    var body: some View {
        // calculates the first date, leading cells, day count, and required number of rows
        let first = calendar.dateInterval(of: .month, for: month)?.start ?? month
        let leadingDays = calendar.component(.weekday, from: first) - 1
        let days = calendar.range(of: .day, in: .month, for: first)?.count ?? 31
        let rows = max(5, (leadingDays + days + 6) / 7)

        VStack(spacing: 8) {
            // displays the month name and year above the grid
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
                // displays the weekday names in Sunday-first order
                ForEach(["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"], id: \.self) { day in
                    Text(day)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 20)

            GeometryReader { geometry in
                // divides the remaining height between rows after subtracting the gaps
                let cellHeight = max(0, (geometry.size.height - CGFloat(rows - 1) * 5) / CGFloat(rows))
                VStack(spacing: 5) {
                    // creates each row and all seven day cells without lazy loading
                    ForEach(0..<rows, id: \.self) { row in
                        HStack(spacing: 5) {
                            ForEach(0..<7, id: \.self) { column in
                                // calculates the cell date and checks whether it belongs to this month
                                let index = row * 7 + column
                                let date = calendar.date(byAdding: .day, value: index - leadingDays, to: first) ?? first
                                let inMonth = index >= leadingDays && index < leadingDays + days
                                // opens the day screen only for dates in this month while browsing
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
        // keeps the calendar text size consistent so saved drawings stay aligned
        .dynamicTypeSize(.large)
    }

    // cell() function
    /// a view returning function that accepts a date, month membership, and height, then displays the day number and border
    private func cell(date: Date, inMonth: Bool, height: CGFloat) -> some View {
        Text("\(calendar.component(.day, from: date))")
            .padding(5)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            .frame(height: height)
            // highlights today and fades dates outside the displayed month
            .gridBox(isTinted: inMonth && calendar.isDateInToday(date))
            .opacity(inMonth ? 1 : 0.3)
            .contentShape(Rectangle())
    }
}
