import SwiftUI
import SwiftData
import UserNotifications

// MARK: - وحدة التذكيرات

struct RemindersView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \ReminderItem.remindAt) private var reminders: [ReminderItem]

    @State private var showEditor = false
    @State private var editingReminder: ReminderItem?

    private var upcoming: [ReminderItem] {
        reminders.filter { !$0.isDone && $0.remindAt > .now }
    }
    private var overdue: [ReminderItem] {
        reminders.filter { !$0.isDone && $0.remindAt <= .now }
    }
    private var finished: [ReminderItem] {
        reminders.filter { $0.isDone }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header

                if overdue.isEmpty && upcoming.isEmpty && finished.isEmpty {
                    emptyState
                }

                if !overdue.isEmpty {
                    ReminderGroup(
                        title: "متأخرة",
                        color: Color(hex: 0xC25450),
                        reminders: overdue,
                        onEdit: { editingReminder = $0 }
                    )
                }

                if !upcoming.isEmpty {
                    ReminderGroup(
                        title: "قادمة",
                        color: Color.appAccent,
                        reminders: upcoming,
                        onEdit: { editingReminder = $0 }
                    )
                }

                if !finished.isEmpty {
                    ReminderGroup(
                        title: "منجزة",
                        color: Color(hex: 0x3E7C4F),
                        reminders: finished,
                        onEdit: { editingReminder = $0 }
                    )
                }
            }
            .padding(.horizontal, 26)
            .padding(.top, 20)
            .padding(.bottom, 30)
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .background(Color.appBackground)
        .navigationTitle("التذكيرات")
        .sheet(isPresented: $showEditor) {
            ReminderEditor(existing: nil)
        }
        .sheet(item: $editingReminder) { reminder in
            ReminderEditor(existing: reminder)
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("التذكيرات")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.appText)
                Text("تنبيهات مجدولة تظهر عبر إشعارات النظام.")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.appMuted)
            }
            Spacer()
            Button {
                showEditor = true
            } label: {
                Label("تذكير جديد", systemImage: "plus")
                    .font(.system(size: 12, weight: .semibold))
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.appAccent)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "bell.slash")
                .font(.system(size: 34))
                .foregroundStyle(Color.appMuted.opacity(0.6))
            Text("لا توجد تذكيرات بعد")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.appMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .surface()
    }
}

// MARK: - مجموعة تذكيرات

struct ReminderGroup: View {
    let title: String
    let color: Color
    let reminders: [ReminderItem]
    let onEdit: (ReminderItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Circle().fill(color).frame(width: 8, height: 8)
                Text(title)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.appText)
                Text("\(reminders.count)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.appMuted)
            }

            VStack(spacing: 8) {
                ForEach(reminders) { reminder in
                    ReminderRow(reminder: reminder, onEdit: { onEdit(reminder) })
                }
            }
        }
    }
}

// MARK: - صف تذكير

struct ReminderRow: View {
    @Environment(\.modelContext) private var context
    let reminder: ReminderItem
    let onEdit: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(reminder.isDone ? Color(hex: 0x3E7C4F).opacity(0.14) : Color.appAccentSoft)
                Image(systemName: reminder.isDone ? "checkmark" : "bell.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(reminder.isDone ? Color(hex: 0x3E7C4F) : Color.appAccent)
            }
            .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 3) {
                Text(reminder.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.appText)
                    .strikethrough(reminder.isDone)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(Fmt.full.string(from: reminder.remindAt))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.appMuted)
                    if reminder.repeatRule != .none {
                        ChipView(label: reminder.repeatRule.label, icon: "arrow.triangle.2.circlepath", color: Color(hex: 0x5B7DA3))
                    }
                }
            }

            Spacer()

            Button {
                toggleDone()
            } label: {
                Image(systemName: reminder.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 16))
                    .foregroundStyle(reminder.isDone ? Color(hex: 0x3E7C4F) : Color.appMuted)
                    .padding(4)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.press)
            .help(reminder.isDone ? "إلغاء الإنجاز" : "وضع علامة منجز")

            Button {
                onEdit()
            } label: {
                Image(systemName: "pencil")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.appMuted)
                    .padding(4)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.press)
        }
        .padding(12)
        .surface()
        .onTapGesture(count: 2) { onEdit() }
        .help("نقرة مزدوجة للتعديل")
        .contextMenu {
            Button("تعديل") { onEdit() }
            Button("حذف التذكير", role: .destructive) {
                cancelNotification()
                context.delete(reminder)
                try? context.save()
            }
        }
    }

    private func toggleDone() {
        reminder.isDone.toggle()
        if reminder.isDone {
            cancelNotification()
        } else {
            NotificationScheduler.schedule(reminder)
        }
        try? context.save()
    }

    private func cancelNotification() {
        if let id = reminder.notificationID {
            UNUserNotificationCenter.current()
                .removePendingNotificationRequests(withIdentifiers: [id])
        }
    }
}

// MARK: - محرر التذكير (بدون Form)

struct ReminderEditor: View {
    let existing: ReminderItem?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var title = ""
    @State private var notes = ""
    @State private var when = Date().addingTimeInterval(3600)
    @State private var repeatRule = ReminderRepeat.none
    @State private var loaded = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(existing == nil ? "تذكير جديد" : "تعديل التذكير")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(Color.appSidebar)

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 6) {
                        FieldLabel(text: "عنوان التذكير")
                        StyledTextField(placeholder: "مثال: اجتماع الفريق الأسبوعي...", text: $title)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        FieldLabel(text: "ملاحظات")
                        StyledTextEditor(placeholder: "تفاصيل إضافية (اختياري)...", text: $notes, minHeight: 70)
                    }

                    HStack {
                        Text("الموعد")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color.appText)
                        Spacer()
                        DatePicker("", selection: $when, displayedComponents: [.date, .hourAndMinute])
                            .labelsHidden()
                            .datePickerStyle(.compact)
                            .fixedSize()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.appField)
                    )

                    MenuPicker(label: "التكرار",
                               selection: $repeatRule,
                               options: ReminderRepeat.allCases.map { ($0, $0.label) })
                }
                .padding(18)
            }

            HStack {
                Spacer()
                Button("إلغاء") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("حفظ") { save() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .tint(Color.appAccent)
                    .disabled(title.isBlank)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color.appSidebar)
        }
        .frame(minWidth: 420, idealWidth: 460, minHeight: 380, idealHeight: 440)
        .applyAppearance()
        .forceRTL()
        .onAppear {
            guard !loaded else { return }
            loaded = true
            if let existing {
                title = existing.title
                notes = existing.notes
                when = existing.remindAt
                repeatRule = existing.repeatRule
            }
        }
    }

    private func save() {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isBlank else { return }

        if let existing {
            existing.title = trimmed
            existing.notes = notes
            existing.remindAt = when
            existing.repeatRule = repeatRule
            NotificationScheduler.schedule(existing)
        } else {
            let reminder = ReminderItem(title: trimmed, notes: notes, remindAt: when, repeatRule: repeatRule)
            context.insert(reminder)
            NotificationScheduler.schedule(reminder)
        }
        try? context.save()
        dismiss()
    }
}

// MARK: - جدولة الإشعارات

enum NotificationScheduler {
    static func schedule(_ reminder: ReminderItem) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = "تذكير"
            content.body = reminder.title
            content.sound = .default

            let components = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: reminder.remindAt
            )
            let trigger = UNCalendarNotificationTrigger(
                dateMatching: components,
                repeats: reminder.repeatRule != .none
            )

            let id = reminder.notificationID ?? UUID().uuidString
            let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
            center.removePendingNotificationRequests(withIdentifiers: [id])
            center.add(request) { _ in }
        }
    }
}
