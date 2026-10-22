import SwiftUI
import SwiftData

// MARK: - وحدة التقويم

struct CalendarView: View {
    @Environment(\.modelContext) private var context
    @Query private var tasks: [TaskItem]

    @State private var monthAnchor = Cal.startOfMonth(.now)
    @State private var selectedDay = Cal.startOfDay(.now)
    @State private var showNewTask = false
    @State private var editingTask: TaskItem?

    private var daysInMonth: Int {
        Cal.gregorian.range(of: .day, in: .month, for: monthAnchor)?.count ?? 30
    }

    private var leadingBlanks: Int {
        let firstDay = Cal.startOfMonth(monthAnchor)
        let weekday = Cal.gregorian.component(.weekday, from: firstDay)
        return (weekday - Cal.gregorian.firstWeekday + 7) % 7
    }

    private var cells: [(day: Int?, date: Date?)] {
        var result: [(Int?, Date?)] = []
        for _ in 0..<leadingBlanks { result.append((nil, nil)) }
        for day in 1...daysInMonth {
            let comps = Cal.gregorian.dateComponents([.year, .month], from: monthAnchor)
            var dayComps = comps
            dayComps.day = day
            if let rawDate = Cal.gregorian.date(from: dayComps) {
                result.append((day, Cal.startOfDay(rawDate)))
            } else {
                result.append((day, nil))
            }
        }
        return result
    }

    private var selectedDayTasks: [TaskItem] {
        let day = selectedDay
        return tasks
            .filter { task in
                guard let due = task.dueDate else { return false }
                return Cal.gregorian.isDate(due, inSameDayAs: day)
            }
            .sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                monthHeader
                weekHeader
                monthGrid
                dayDetails
            }
            .padding(.horizontal, 26)
            .padding(.top, 20)
            .padding(.bottom, 30)
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .background(Color.appBackground)
        .navigationTitle("التقويم")
        .sheet(isPresented: $showNewTask) {
            TaskEditor(mode: .new(status: .todo, dueDate: selectedDay))
                .frame(minWidth: 460, minHeight: 540)
        }
        .sheet(item: $editingTask) { task in
            TaskEditor(mode: .edit(task))
                .applyAppearance()
                .forceRTL()
        }
    }

    // MARK: ترويسة الشهر

    private var monthHeader: some View {
        HStack(spacing: 10) {
            Button {
                monthAnchor = Cal.startOfMonth(Cal.addMonths(1, to: monthAnchor))
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 12, weight: .semibold))
            }
            .buttonStyle(.bordered)
            .help("الشهر التالي")

            Text(Fmt.monthYear.string(from: monthAnchor))
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(Color.appText)

            Button {
                monthAnchor = Cal.startOfMonth(Cal.addMonths(-1, to: monthAnchor))
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
            }
            .buttonStyle(.bordered)
            .help("الشهر السابق")

            Spacer()

            Button {
                monthAnchor = Cal.startOfMonth(.now)
                selectedDay = Cal.startOfDay(.now)
            } label: {
                Text("اليوم")
                    .font(.system(size: 12, weight: .semibold))
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.appAccent)
        }
    }

    private var weekHeader: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 6) {
            ForEach(Fmt.weekdaySymbols, id: \.self) { symbol in
                Text(symbol)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.appMuted)
            }
        }
    }

    private var monthGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 6) {
            ForEach(Array(cells.enumerated()), id: \.offset) { _, cell in
                if let date = cell.date {
                    DayCell(
                        date: date,
                        tasks: tasks.filter {
                            guard let due = $0.dueDate else { return false }
                            return Cal.gregorian.isDate(due, inSameDayAs: date)
                        },
                        isSelected: Cal.gregorian.isDate(date, inSameDayAs: selectedDay),
                        isToday: Cal.gregorian.isDateInToday(date)
                    ) {
                        selectedDay = date
                    }
                } else {
                    Color.clear.frame(height: 66)
                }
            }
        }
    }

    private var dayDetails: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("مهام يوم " + Fmt.dayMonthYear.string(from: selectedDay))
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.appText)
                Spacer()
                Button {
                    showNewTask = true
                } label: {
                    Label("إضافة مهمة في هذا اليوم", systemImage: "plus")
                        .font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.appAccent)
            }

            let list = selectedDayTasks
            if list.isEmpty {
                Text("لا توجد مهام في هذا اليوم.")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.appMuted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .surface()
            } else {
                VStack(spacing: 8) {
                    ForEach(list) { task in
                        FeaturedTaskRow(task: task, onEdit: { editingTask = task })
                    }
                }
            }
        }
        .padding(.top, 6)
    }
}

// MARK: - خلية يوم

struct DayCell: View {
    let date: Date
    let tasks: [TaskItem]
    let isSelected: Bool
    let isToday: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Text("\(Cal.gregorian.component(.day, from: date))")
                    .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                    .foregroundStyle(isSelected ? Color.white : (isToday ? Color.appAccent : Color.appText))

                HStack(spacing: 3) {
                    let pending = tasks.filter { !$0.isCompleted }.prefix(3)
                    if pending.isEmpty && !tasks.isEmpty {
                        Circle().fill(Color(hex: 0x3E7C4F)).frame(width: 4, height: 4)
                    }
                    ForEach(pending) { task in
                        Circle()
                            .fill(task.priority.color)
                            .frame(width: 4, height: 4)
                    }
                }
                .frame(height: 6)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 60)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? Color.appAccent : Color.appCard)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(isToday ? Color.appAccent : Color.appBorder, lineWidth: isToday ? 1.5 : 1)
            )
        }
        .buttonStyle(.press)
    }
}
