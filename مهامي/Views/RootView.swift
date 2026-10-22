import SwiftUI
import SwiftData

// MARK: - أقسام التطبيق

enum AppSection: String, CaseIterable, Identifiable {
    case dashboard
    case tasks
    case calendar
    case reminders
    case scratchpad
    case bookmarks
    case settings
    case about

    var id: String { rawValue }

    var label: String {
        switch self {
        case .dashboard: return "لوحة اليوم"
        case .tasks: return "المهام"
        case .calendar: return "التقويم"
        case .reminders: return "التذكيرات"
        case .scratchpad: return "ملاحظاتي"
        case .bookmarks: return "العلامات"
        case .settings: return "الإعدادات"
        case .about: return "حول التطبيق"
        }
    }

    var icon: String {
        switch self {
        case .dashboard: return "square.grid.2x2"
        case .tasks: return "rectangle.split.3x1"
        case .calendar: return "calendar"
        case .reminders: return "bell"
        case .scratchpad: return "note.text"
        case .bookmarks: return "bookmark"
        case .settings: return "gearshape"
        case .about: return "info.circle"
        }
    }
}

// MARK: - الواجهة الرئيسية

struct RootView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.openWindow) private var openWindow

    @AppStorage("selectedSection") private var selectedRaw = AppSection.dashboard.rawValue

    @Query private var tasks: [TaskItem]
    @Query private var notes: [Note]
    @Query private var reminders: [ReminderItem]
    @Query private var bookmarks: [Bookmark]

    @ObservedObject private var windowManager = WindowManager.shared

    private var selection: Binding<AppSection> {
        Binding(
            get: { AppSection(rawValue: selectedRaw) ?? .dashboard },
            set: { selectedRaw = $0.rawValue }
        )
    }

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 200, ideal: 222, max: 300)
                .navigationTitle(AppInfo.name)
        } detail: {
            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .task {
            if let config = AppSchema.container.configurations.first {
                AppSchema.migrationLog.info("الحاوية: url=\(config.url.path, privacy: .public) cloud=\(String(describing: config.cloudKitDatabase), privacy: .public) iCloudAccount=\(String(describing: FileManager.default.ubiquityIdentityToken), privacy: .public)")
            }
            AppSchema.migrationLog.info("وضع التخزين: \(AppSchema.usesiCloud ? "iCloud/CloudKit" : "محلي", privacy: .public)")
            AppSchema.migrateLegacyStoreIfNeeded(context: context)
            SeedData.seedIfNeeded(context: context)
        }
    }

    // MARK: الشريط الجانبي

    private var sidebar: some View {
        VStack(spacing: 0) {
            VStack(spacing: 2) {
                ForEach(AppSection.allCases) { section in
                    SidebarRow(
                        section: section,
                        badge: badge(for: section),
                        isSelected: selection.wrappedValue == section,
                        action: { selection.wrappedValue = section }
                    )
                }
            }
            .padding(.top, 8)

            Spacer()

            quickNoteToggle
        }
        .padding(.horizontal, 10)
        .padding(.top, 6)
        .padding(.bottom, 12)
        .background(Color.appSidebar)
        .ignoresSafeArea(edges: .bottom)
    }

    private func badge(for section: AppSection) -> String? {
        switch section {
        case .tasks: return "\(tasks.filter { !$0.isCompleted }.count)"
        case .scratchpad: return notes.isEmpty ? nil : "\(notes.count)"
        case .bookmarks: return bookmarks.isEmpty ? nil : "\(bookmarks.count)"
        case .reminders:
            let count = reminders.filter { !$0.isDone }.count
            return count == 0 ? nil : "\(count)"
        default: return nil
        }
    }

    // MARK: زر إظهار/إخفاء الملاحظة السريعة

    private var quickNoteToggle: some View {
        Button {
            if windowManager.isQuickNoteVisible {
                windowManager.hideQuickNote()
            } else {
                openWindow(id: "quick-note")
            }
        } label: {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.appAccentSoft)
                    Image(systemName: "note.text")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.appAccent)
                }
                .frame(width: 32, height: 32)

                VStack(alignment: .leading, spacing: 1) {
                    Text("ملاحظة سريعة")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.appText)
                    Text(windowManager.isQuickNoteVisible ? "النافذة ظاهرة — انقر للإخفاء" : "نافذة عائمة صغيرة")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.appMuted)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: windowManager.isQuickNoteVisible ? "stop.circle.fill" : "play.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(Color.appAccent)
            }
            .padding(8)
            .surface(cornerRadius: 10)
        }
        .buttonStyle(.press)
    }

    // MARK: تفاصيل القسم

    @ViewBuilder
    private var detail: some View {
        switch selection.wrappedValue {
        case .dashboard:
            DashboardView(selection: selection)
        case .tasks:
            TasksView()
        case .calendar:
            CalendarView()
        case .reminders:
            RemindersView()
        case .scratchpad:
            ScratchpadView()
        case .bookmarks:
            BookmarksView()
        case .settings:
            SettingsMainView()
        case .about:
            AboutView()
        }
    }
}

// MARK: - صف الشريط الجانبي

struct SidebarRow: View {
    let section: AppSection
    let badge: String?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: section.icon)
                    .font(.system(size: 14, weight: .medium))
                    .frame(width: 18)
                Text(section.label)
                    .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                Spacer()
                if let badge {
                    Text(badge)
                        .font(.system(size: 10, weight: .semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(isSelected ? Color.white.opacity(0.25) : Color.appMuted.opacity(0.18)))
                        .foregroundStyle(isSelected ? Color.white : Color.appMuted)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .foregroundStyle(isSelected ? Color.white : Color.appText)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? Palette.highlight : Color.clear)
            )
        }
        .buttonStyle(.press)
    }
}

// MARK: - إنشاء البيانات الافتراضية

enum SeedData {
    static func seedIfNeeded(context: ModelContext) {
        let folderDescriptor = FetchDescriptor<Folder>()
        let folders = (try? context.fetch(folderDescriptor)) ?? []
        if folders.isEmpty {
            for name in AppConstants.defaultFolderNames {
                context.insert(Folder(name: name))
            }
        }
        let hasQuickFolder = folders.contains { $0.name == AppConstants.quickNoteFolderName }
        if !hasQuickFolder {
            context.insert(Folder(name: AppConstants.quickNoteFolderName))
        }
    }
}
