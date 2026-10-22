import SwiftUI
import SwiftData

struct DashboardView: View {
    @Binding var selection: AppSection
    @Environment(\.modelContext) private var context
    @Environment(\.openWindow) private var openWindow

    @Query private var tasks: [TaskItem]
    @Query private var notes: [Note]
    @Query private var reminders: [ReminderItem]

    @State private var editingTask: TaskItem?

    private var pendingTasks: [TaskItem] { tasks.filter { !$0.isCompleted } }
    private var completedTasks: [TaskItem] { tasks.filter { $0.isCompleted } }
    private var upcomingReminders: [ReminderItem] {
        reminders.filter { !$0.isDone && $0.remindAt > .now }
    }
    private var dueSoonTasks: [TaskItem] {
        let today = Cal.startOfDay(.now)
        let limit = Cal.gregorian.date(byAdding: .day, value: 7, to: today) ?? today
        return TaskOrdering.sort(
            pendingTasks.filter { task in
                guard let due = task.dueDate else { return false }
                return due >= today && due <= limit
            }
        )
    }
    private var featuredTasks: [TaskItem] {
        TaskOrdering.sort(pendingTasks)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                statsGrid
                if !upcomingReminders.isEmpty {
                    nextReminderBanner
                }
                dueSoonSection
                featuredSection
            }
            .padding(.horizontal, 26)
            .padding(.top, 22)
            .padding(.bottom, 30)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .background(Color.appBackground)
        .navigationTitle("لوحة اليوم")
        .sheet(item: $editingTask) { task in
            TaskEditor(mode: .edit(task))
                .applyAppearance()
                .forceRTL()
        }
    }

    // MARK: الترويسة

    private var hour: Int {
        Cal.gregorian.component(.hour, from: .now)
    }

    private var greeting: String {
        switch hour {
        case 5..<12: return "صباح الخير"
        case 12..<17: return "نهارك سعيد"
        default: return "مساء الخير"
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.appAccentSoft)
                    Image(systemName: hour < 17 ? "sun.max" : "moon.stars")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(Color.appAccent)
                }
                .frame(width: 52, height: 52)

                VStack(alignment: .leading, spacing: 3) {
                    Text(greeting)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.appText)
                    Text("تابع تدفق يومك وأنجز مهامك الأهم أولاً.")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.appMuted)
                }
            }

            Spacer()

            Button {
                openWindow(id: "quick-note")
            } label: {
                Label("ملاحظة سريعة", systemImage: "bolt.fill")
                    .font(.system(size: 13, weight: .semibold))
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.appAccent)
        }
    }

    // MARK: بطاقات الإحصاء

    private var statsGrid: some View {
        HStack(spacing: 14) {
            StatCard(icon: "list.bullet.circle.fill",
                     tint: Color(hex: 0xC08A3E),
                     value: "\(pendingTasks.count)",
                     title: "مهام معلّقة",
                     subtitle: "مهام بانتظار الإنجاز")
            StatCard(icon: "checkmark.seal.fill",
                     tint: Color(hex: 0x3E7C4F),
                     value: "\(completedTasks.count)",
                     title: "مهام منجزة",
                     subtitle: "استمر في نفس الزخم!")
            StatCard(icon: "note.text",
                     tint: Color(hex: 0x5B7DA3),
                     value: "\(notes.count)",
                     title: "ملاحظات",
                     subtitle: "في ملاحظاتي")
            StatCard(icon: "bell.fill",
                     tint: Color(hex: 0x8E5BA6),
                     value: "\(upcomingReminders.count)",
                     title: "تذكيرات قادمة",
                     subtitle: "مفعّلة ومجدولة")
        }
    }

    // MARK: التذكير التالي

    private var nextReminderBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "bell.badge.fill")
                .foregroundStyle(Color(hex: 0x8E5BA6))
            VStack(alignment: .leading, spacing: 2) {
                Text("التذكير القادم")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.appMuted)
                Text(upcomingReminders.map { $0.remindAt }.min().map { Fmt.full.string(from: $0) } ?? "")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.appText)
            }
            Spacer()
        }
        .padding(14)
        .surface()
    }

    // MARK: مهام مستحقة قريبًا

    private var dueSoonSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("مهام مستحقّة قريبًا")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.appText)
                if !dueSoonTasks.isEmpty {
                    Text("\(dueSoonTasks.count) مهام")
                        .font(.system(size: 11, weight: .semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color(hex: 0xC08A3E).opacity(0.15)))
                        .foregroundStyle(Color(hex: 0xC08A3E))
                }
                Spacer()
                Button("عرض كل المهام") { selection = .tasks }
                    .font(.system(size: 12, weight: .medium))
                    .buttonStyle(.borderless)
                    .foregroundStyle(Color.appAccent)
            }

            if dueSoonTasks.isEmpty {
                Text("لا توجد مهام مستحقّة خلال 7 أيام المقبلة.")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.appMuted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .surface()
            } else {
                HStack(spacing: 12) {
                    ForEach(dueSoonTasks.prefix(4)) { task in
                        DueSoonCard(task: task, onEdit: { editingTask = task })
                    }
                }
            }
        }
    }

    // MARK: المهام البارزة

    private var featuredSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("المهام البارزة")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.appText)
                Spacer()
                Button("عرض الكل") { selection = .tasks }
                    .font(.system(size: 12, weight: .medium))
                    .buttonStyle(.borderless)
                    .foregroundStyle(Color.appAccent)
            }

            let list = featuredTasks.prefix(5)
            if list.isEmpty {
                Text("لا توجد مهام بعد — أضف مهمتك الأولى من شاشة المهام.")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.appMuted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .surface()
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(list)) { task in
                        FeaturedTaskRow(task: task, onEdit: { editingTask = task })
                    }
                }
            }
        }
    }
}

// MARK: - بطاقة إحصاء

struct StatCard: View {
    let icon: String
    let tint: Color
    let value: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(tint.opacity(0.14))
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(tint)
            }
            .frame(width: 34, height: 34)

            Text(value)
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(Color.appText)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.appText)
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.appMuted)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .surface()
    }
}

// MARK: - بطاقة مستحقّة قريبًا

struct DueSoonCard: View {
    @Environment(\.modelContext) private var context
    let task: TaskItem
    let onEdit: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(task.priority.color.opacity(0.14))
                Text(task.priority.badge)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(task.priority.color)
            }
            .frame(width: 30, height: 30)

            VStack(alignment: .leading, spacing: 3) {
                Text(task.title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.appText)
                    .lineLimit(1)
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.system(size: 9))
                    Text(Fmt.due(task.dueDate ?? .now))
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundStyle(Color.appMuted)
            }

            Spacer()

            Button {
                task.toggleCompleted()
                try? context.save()
            } label: {
                Image(systemName: "circle")
                    .font(.system(size: 15))
                    .foregroundStyle(Color.appMuted)
            }
            .buttonStyle(.press)
            .help("وضع علامة مكتملة")
        }
        .padding(12)
        .frame(width: 190, alignment: .leading)
        .surface()
        .onTapGesture(count: 2) { onEdit() }
        .help("نقرة مزدوجة للتعديل")
    }
}

// MARK: - صف مهمة بارزة

struct FeaturedTaskRow: View {
    @Environment(\.modelContext) private var context
    let task: TaskItem
    let onEdit: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button {
                task.toggleCompleted()
                try? context.save()
            } label: {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 15))
                    .foregroundStyle(task.isCompleted ? Color(hex: 0x3E7C4F) : Color.appMuted)
            }
            .buttonStyle(.press)

            Text(task.title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.appText)
                .strikethrough(task.isCompleted)
                .lineLimit(1)

            Spacer()

            if let due = task.dueDate, !task.isCompleted {
                Text(Fmt.due(due))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(due < Cal.startOfDay(.now) ? Color(hex: 0xC25450) : Color.appMuted)
            }

            ChipView(label: task.priority.label, icon: task.priority.symbol, color: task.priority.color)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .surface()
        .onTapGesture(count: 2) { onEdit() }
        .help("نقرة مزدوجة للتعديل")
    }
}
