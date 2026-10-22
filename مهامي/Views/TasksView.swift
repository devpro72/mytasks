import SwiftUI
import SwiftData
import AppKit

// MARK: - وحدة المهام (لوحة كانبان + قائمة)

struct TasksView: View {
    @Environment(\.modelContext) private var context

    @Query(sort: \TaskItem.createdAt, order: .reverse) private var allTasks: [TaskItem]
    @Query(sort: \Project.createdAt) private var projects: [Project]

    @State private var searchText = ""
    @State private var isListView = false
    @State private var projectFilter: Project?
    @State private var newTaskStatus: TaskStatus = .todo
    @State private var showNewTask = false
    @State private var editingTask: TaskItem?
    @State private var showProjectPopover = false
    @State private var newProjectName = ""
    @State private var newProjectEmoji = "📁"

    private func commit() { try? context.save() }

    var body: some View {
        VStack(spacing: 14) {
            header
            projectFilterRow

            if isListView {
                listView
            } else {
                kanbanView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 16)
        .background(Color.appBackground)
        .navigationTitle("لوحة المهام")
        .sheet(isPresented: $showNewTask) {
            TaskEditor(mode: .new(status: newTaskStatus, dueDate: nil))
        }
        .sheet(item: $editingTask) { task in
            TaskEditor(mode: .edit(task))
        }
        .popover(isPresented: $showProjectPopover) {
            ProjectForm(
                name: $newProjectName,
                emoji: $newProjectEmoji
            ) {
                addProject()
            }
        }
    }

    // MARK: الترويسة

    private var header: some View {
        HStack(spacing: 12) {
            Text("لوحة المهام")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(Color.appText)
                .layoutPriority(1)

            Spacer()

            Picker("طريقة العرض", selection: $isListView) {
                Image(systemName: "rectangle.split.3x1").tag(false)
                Image(systemName: "list.bullet").tag(true)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()

            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.appMuted)
                TextField("ابحث في المهام...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .frame(minWidth: 160, idealWidth: 220, maxWidth: 260)
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.appField))

            Button {
                newTaskStatus = .todo
                showNewTask = true
            } label: {
                Label("مهمة جديدة", systemImage: "plus")
                    .font(.system(size: 12, weight: .semibold))
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.appAccent)
        }
    }

    // MARK: صف تصفية المشاريع

    private var projectFilterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterChip(title: "كل المهام", emoji: nil, isSelected: projectFilter == nil) {
                    projectFilter = nil
                }

                ForEach(projects) { project in
                    filterChip(title: project.name, emoji: project.emoji, isSelected: projectFilter == project) {
                        projectFilter = projectFilter == project ? nil : project
                    }
                    .contextMenu {
                        Button("حذف المشروع", role: .destructive) { deleteProject(project) }
                    }
                }

                Button {
                    newProjectName = ""
                    newProjectEmoji = "📁"
                    showProjectPopover = true
                } label: {
                    Label("مشروع جديد", systemImage: "plus")
                        .font(.system(size: 11, weight: .semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(Color.appBorder.opacity(0.4)))
                        .foregroundStyle(Color.appMuted)
                }
                .buttonStyle(.press)
            }
            .padding(.vertical, 2)
        }
    }

    private func filterChip(title: String, emoji: String?, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if let emoji {
                    Text(emoji)
                        .font(.system(size: 11))
                }
                Text(title)
                    .font(.system(size: 11, weight: isSelected ? .bold : .medium))
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule().fill(isSelected ? Color.appAccent : Color.appCard)
            )
            .overlay(
                Capsule().strokeBorder(isSelected ? Color.clear : Color.appBorder, lineWidth: 1)
            )
            .foregroundStyle(isSelected ? Color.white : Color.appText)
        }
        .buttonStyle(.press)
    }

    // MARK: عرض كانبان (أعمدة متساوية تملأ العرض — بلا تمرير أفقي)

    private var kanbanView: some View {
        HStack(alignment: .top, spacing: 14) {
            ForEach(TaskStatus.allCases) { status in
                KanbanColumn(
                    status: status,
                    tasks: filtered(by: status),
                    onAdd: {
                        newTaskStatus = status
                        showNewTask = true
                    },
                    onEdit: { editingTask = $0 }
                )
                .frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: عرض القائمة

    private var listView: some View {
        VStack(spacing: 8) {
            let list = TaskOrdering.sort(filteredAll)
            if list.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(list) { task in
                            TaskListRow(task: task, onEdit: { editingTask = task })
                        }
                    }
                }
                .frame(maxHeight: .infinity)
            }
        }
        .frame(maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "list.bullet.rectangle.portrait")
                .font(.system(size: 34))
                .foregroundStyle(Color.appMuted.opacity(0.6))
            Text("لا توجد مهام مطابقة")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.appMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: التصفية والفرز

    private func filtered(by status: TaskStatus) -> [TaskItem] {
        TaskOrdering.sort(filteredAll.filter { $0.status == status })
    }

    private var filteredAll: [TaskItem] {
        var list = allTasks
        if let project = projectFilter {
            list = list.filter { $0.project == project }
        }
        if !searchText.isBlank {
            list = list.filter {
                $0.title.localizedStandardContains(searchText) ||
                $0.details.localizedStandardContains(searchText)
            }
        }
        return list
    }

    private func addProject() {
        let name = newProjectName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isBlank else { return }
        let emoji = newProjectEmoji.isBlank ? "📁" : String(newProjectEmoji.prefix(2))
        let project = Project(name: name, emoji: emoji)
        context.insert(project)
        commit()
        projectFilter = project
        newProjectName = ""
    }

    private func deleteProject(_ project: Project) {
        context.delete(project)
        commit()
        if projectFilter == project {
            projectFilter = nil
        }
    }
}

// MARK: - عمود كانبان

struct KanbanColumn: View {
    let status: TaskStatus
    let tasks: [TaskItem]
    let onAdd: () -> Void
    let onEdit: (TaskItem) -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Circle()
                    .fill(status.dotColor)
                    .frame(width: 9, height: 9)
                Text(status.label)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.appText)
                Text("\(tasks.count)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.appMuted)
                Spacer()
                Button(action: onAdd) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.appMuted)
                        .padding(4)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.press)
                .help("إضافة مهمة هنا")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            Divider().overlay(Color.appBorder)

            if tasks.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: status == .inProgress ? "hourglass" : "tray")
                        .font(.system(size: 22))
                        .foregroundStyle(Color.appMuted.opacity(0.55))
                    Text(status == .inProgress ? "لا توجد مهام قيد التنفيذ" : "لا توجد مهام")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.appMuted)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(tasks) { task in
                            TaskCard(task: task, onEdit: { onEdit(task) })
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.top, 10)
                    .padding(.bottom, 12)
                }
                .frame(maxHeight: .infinity)
                .scrollIndicators(.hidden)
            }

            Divider().overlay(Color.appBorder)

            Button {
                onAdd()
            } label: {
                Label("إضافة مهمة", systemImage: "plus")
                    .font(.system(size: 12, weight: .medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
            }
            .buttonStyle(.press)
            .foregroundStyle(Color.appMuted)
        }
        .frame(maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.appCard.opacity(0.6))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.appBorder, lineWidth: 1)
                )
        )
    }
}

// MARK: - بطاقة مهمة

struct TaskCard: View {
    @Environment(\.modelContext) private var context
    let task: TaskItem
    let onEdit: () -> Void

    private func commit() { try? context.save() }

    private var isOverdue: Bool {
        guard let due = task.dueDate, !task.isCompleted else { return false }
        return due < Cal.startOfDay(.now)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                ChipView(label: task.priority.label,
                         icon: task.priority.symbol,
                         color: task.priority.color,
                         filled: task.priority != .none)
                Spacer()
                Menu {
                    Button("تعديل المهمة") { onEdit() }
                    Menu("نقل إلى") {
                        ForEach(TaskStatus.allCases) { target in
                            Button(target.label) { task.moveTo(target); commit() }
                        }
                    }
                    Divider()
                    Button("حذف المهمة", role: .destructive) { delete() }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 11))
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(Color.appMuted.opacity(0.12)))
                        .foregroundStyle(Color.appMuted)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()

                Button {
                    delete()
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 10))
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(Color(hex: 0xC25450).opacity(0.12)))
                        .foregroundStyle(Color(hex: 0xC25450))
                }
                .buttonStyle(.press)
                .help("حذف المهمة")
            }

            Text(task.title)
                .font(.system(size: 13.5, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.appText)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            if task.isCompleted {
                Text("مكتملة")
                    .strikethrough()
                    .font(.system(size: 11))
                    .foregroundStyle(Color(hex: 0x3E7C4F))
            }

            if let due = task.dueDate {
                HStack(spacing: 5) {
                    Image(systemName: "calendar")
                        .font(.system(size: 10))
                    Text("تاريخ الاستحقاق: " + Fmt.due(due))
                        .font(.system(size: 11, weight: .medium))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(isOverdue ? Color(hex: 0xC25450).opacity(0.12) : Color.appField))
                .foregroundStyle(isOverdue ? Color(hex: 0xC25450) : Color.appMuted)
            }

            if let project = task.project {
                HStack(spacing: 5) {
                    Text(project.emoji)
                        .font(.system(size: 10))
                    Text(project.name)
                        .font(.system(size: 11, weight: .medium))
                        .lineLimit(1)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color.appAccentSoft))
                .foregroundStyle(Color.appAccent)
            }

            Divider().overlay(Color.appBorder.opacity(0.6))

            HStack(spacing: 5) {
                Text("نقل:")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color.appMuted)
                ForEach(TaskStatus.allCases) { target in
                    Button {
                        task.moveTo(target)
                        commit()
                    } label: {
                        Text(target.label)
                            .font(.system(size: 10, weight: .semibold))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(
                                Capsule().fill(task.status == target ? target.dotColor.opacity(0.16) : Color.appField)
                            )
                            .foregroundStyle(task.status == target ? target.dotColor : Color.appMuted)
                    }
                    .buttonStyle(.press)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .surface(cornerRadius: 12)
        .onTapGesture(count: 2) { onEdit() }
        .help("نقرة مزدوجة للتعديل")
    }

    private func delete() {
        context.delete(task)
        commit()
    }
}

// MARK: - صف قائمة المهام

struct TaskListRow: View {
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

            if let project = task.project {
                HStack(spacing: 3) {
                    Text(project.emoji)
                    Text(project.name)
                        .font(.system(size: 10, weight: .medium))
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(Capsule().fill(Color.appAccentSoft))
                .foregroundStyle(Color.appAccent)
            }

            if let due = task.dueDate {
                Text(Fmt.due(due))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(due < Cal.startOfDay(.now) && !task.isCompleted ? Color(hex: 0xC25450) : Color.appMuted)
            }

            Spacer()

            ChipView(label: task.priority.label, icon: task.priority.symbol, color: task.priority.color, filled: task.priority != .none)

            Button {
                onEdit()
            } label: {
                Image(systemName: "pencil")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.appMuted)
                    .padding(4)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.press)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .surface()
        .onTapGesture(count: 2) { onEdit() }
        .help("نقرة مزدوجة للتعديل")
        .contextMenu {
            Button("تعديل") { onEdit() }
            Menu("نقل إلى") {
                ForEach(TaskStatus.allCases) { target in
                    Button(target.label) {
                        task.moveTo(target)
                        try? context.save()
                    }
                }
            }
            Divider()
            Button("حذف المهمة", role: .destructive) {
                context.delete(task)
                try? context.save()
            }
        }
    }
}

// MARK: - نموذج مشروع جديد

struct ProjectForm: View {
    @Binding var name: String
    @Binding var emoji: String
    let onSubmit: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("مشروع جديد")
                .font(.system(size: 14, weight: .bold, design: .rounded))

            TextField("اسم المشروع", text: $name)
                .textFieldStyle(.roundedBorder)

            TextField("رمز (إيموجي)", text: $emoji)
                .textFieldStyle(.roundedBorder)
                .frame(width: 140)

            HStack {
                Spacer()
                Button("إلغاء") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("إضافة") {
                    onSubmit()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(name.isBlank)
            }
        }
        .padding(16)
        .frame(width: 260)
    }
}

// MARK: - محرر المهمة (بدون Form — يمنع أي تكدّس)

struct TaskEditor: View {
    enum Mode {
        case new(status: TaskStatus, dueDate: Date?)
        case edit(TaskItem)

        var task: TaskItem? {
            if case .edit(let task) = self { return task }
            return nil
        }
    }

    let mode: Mode

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \Project.createdAt) private var projects: [Project]

    @State private var title = ""
    @State private var details = ""
    @State private var priority: TaskPriority = .none
    @State private var status: TaskStatus = .todo
    @State private var hasDue = false
    @State private var dueDate = Date()
    @State private var project: Project?
    @State private var loaded = false

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 6) {
                        FieldLabel(text: "عنوان المهمة")
                        StyledTextField(placeholder: "مثال: إعداد تقرير شهري...", text: $title)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        FieldLabel(text: "التفاصيل")
                        StyledTextEditor(placeholder: "أضف تفاصيل أو ملاحظات (اختياري)...", text: $details, minHeight: 90)
                    }

                    MenuPicker(label: "الأولوية",
                               selection: $priority,
                               options: TaskPriority.allCases.map { ($0, $0.label) })

                    MenuPicker(label: "الحالة",
                               selection: $status,
                               options: TaskStatus.allCases.map { ($0, $0.label) })

                    projectRow

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("تاريخ الاستحقاق")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Color.appText)
                            Spacer()
                            Toggle("", isOn: $hasDue)
                                .toggleStyle(.switch)
                                .labelsHidden()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.appField)
                        )

                        if hasDue {
                            DatePicker("", selection: $dueDate, displayedComponents: [.date])
                                .labelsHidden()
                                .datePickerStyle(.compact)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .padding(18)
            }

            footer
        }
        .frame(minWidth: 440, idealWidth: 480, minHeight: 460, idealHeight: 580)
        .applyAppearance()
        .forceRTL()
        .onAppear(perform: load)
    }

    private var header: some View {
        HStack {
            Text(mode.task == nil ? "مهمة جديدة" : "تعديل المهمة")
                .font(.system(size: 17, weight: .bold, design: .rounded))
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Color.appSidebar)
    }

    private var footer: some View {
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

    private var projectRow: some View {
        HStack {
            Text("المشروع")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.appText)
            Spacer()
            Menu {
                Button("بدون مشروع") { project = nil }
                ForEach(projects) { p in
                    Button("\(p.emoji) \(p.name)") { project = p }
                }
            } label: {
                HStack(spacing: 6) {
                    if let p = project {
                        Text(p.emoji)
                            .font(.system(size: 12))
                        Text(p.name)
                            .font(.system(size: 12, weight: .medium))
                            .lineLimit(1)
                    } else {
                        Text("بدون مشروع")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color.appMuted)
                    }
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 9))
                        .foregroundStyle(Color.appMuted)
                }
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.appField)
        )
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        switch mode {
        case .new(let presetStatus, let presetDue):
            status = presetStatus
            if let presetDue {
                hasDue = true
                dueDate = presetDue
            }
        case .edit(let task):
            title = task.title
            details = task.details
            priority = task.priority
            status = task.status
            project = task.project
            if let due = task.dueDate {
                hasDue = true
                dueDate = due
            }
        }
    }

    private func save() {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isBlank else { return }

        let finalDue: Date? = hasDue ? Cal.startOfDay(dueDate) : nil

        switch mode {
        case .new:
            let task = TaskItem(title: trimmed,
                                details: details,
                                status: status,
                                priority: priority,
                                dueDate: finalDue,
                                project: project)
            context.insert(task)
        case .edit(let task):
            task.title = trimmed
            task.details = details
            task.priority = priority
            task.project = project
            task.dueDate = finalDue
            task.moveTo(status)
        }
        try? context.save()
        dismiss()
    }
}
