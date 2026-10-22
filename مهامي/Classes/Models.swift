import Foundation
import SwiftData
import SwiftUI

// MARK: - حالة المهمة (أعمدة كانبان)

enum TaskStatus: String, CaseIterable, Codable, Identifiable {
    case todo
    case inProgress
    case done

    var id: String { rawValue }

    var label: String {
        switch self {
        case .todo: return "قائمة الانتظار"
        case .inProgress: return "قيد التنفيذ"
        case .done: return "مكتملة"
        }
    }

    var dotColor: Color {
        switch self {
        case .todo: return Color(hex: 0x46586E)
        case .inProgress: return Color(hex: 0xE0965A)
        case .done: return Color(hex: 0x3E7C4F)
        }
    }
}

// MARK: - أولوية المهمة

enum TaskPriority: String, CaseIterable, Codable, Identifiable {
    case none
    case low
    case medium
    case high

    var id: String { rawValue }

    var label: String {
        switch self {
        case .none: return "بدون"
        case .low: return "منخفضة"
        case .medium: return "متوسطة"
        case .high: return "عالية"
        }
    }

    var badge: String {
        switch self {
        case .none: return "·"
        case .low: return "↓"
        case .medium: return "="
        case .high: return "!"
        }
    }

    /// اسم أيقونة نظام صالح (SF Symbols) للاستخدام في Image(systemName:)
    var symbol: String {
        switch self {
        case .none: return "minus"
        case .low: return "arrow.down"
        case .medium: return "equal"
        case .high: return "exclamationmark"
        }
    }

    var color: Color {
        switch self {
        case .none: return Color(hex: 0x8C897E)
        case .low: return Color(hex: 0x5B7DA3)
        case .medium: return Color(hex: 0xC08A3E)
        case .high: return Color(hex: 0xC25450)
        }
    }

    var sortIndex: Int {
        switch self {
        case .high: return 0
        case .medium: return 1
        case .low: return 2
        case .none: return 3
        }
    }
}

// MARK: - تكرار التذكير

enum ReminderRepeat: String, CaseIterable, Codable, Identifiable {
    case none
    case daily
    case weekly
    case monthly

    var id: String { rawValue }

    var label: String {
        switch self {
        case .none: return "بدون تكرار"
        case .daily: return "يوميًا"
        case .weekly: return "أسبوعيًا"
        case .monthly: return "شهريًا"
        }
    }
}

// MARK: - تصنيف علامة مرجعية

enum BookmarkCategory: String, CaseIterable, Codable, Identifiable {
    case reference
    case tools
    case docs
    case design
    case work

    var id: String { rawValue }

    var label: String {
        switch self {
        case .reference: return "مرجع"
        case .tools: return "أدوات"
        case .docs: return "مستندات"
        case .design: return "تصميم"
        case .work: return "عمل"
        }
    }
}

// MARK: - النماذج

@Model
final class Project {
    var name: String = ""
    var emoji: String = "📁"
    var createdAt: Date = Date.now

    /// العلاقة العكسية اختيارية إلزام الـ CloudKit
    @Relationship(deleteRule: .nullify, inverse: \TaskItem.project)
    var tasks: [TaskItem]? = nil

    init(name: String, emoji: String = "📁", createdAt: Date = .now) {
        self.name = name
        self.emoji = emoji
        self.createdAt = createdAt
    }
}

@Model
final class TaskItem {
    var title: String = ""
    var details: String = ""
    var statusRaw: String = TaskStatus.todo.rawValue
    var priorityRaw: String = TaskPriority.none.rawValue
    var dueDate: Date?
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now
    var completedAt: Date?
    var project: Project?

    var status: TaskStatus {
        get { TaskStatus(rawValue: statusRaw) ?? .todo }
    }

    var priority: TaskPriority {
        get { TaskPriority(rawValue: priorityRaw) ?? .none }
        set { priorityRaw = newValue.rawValue }
    }

    var isCompleted: Bool { status == .done }

    init(title: String,
         details: String = "",
         status: TaskStatus = .todo,
         priority: TaskPriority = .none,
         dueDate: Date? = nil,
         project: Project? = nil) {
        self.title = title
        self.details = details
        self.statusRaw = status.rawValue
        self.priorityRaw = priority.rawValue
        self.dueDate = dueDate
        self.createdAt = .now
        self.updatedAt = .now
        self.completedAt = status == .done ? .now : nil
        self.project = project
    }

    func moveTo(_ newStatus: TaskStatus) {
        statusRaw = newStatus.rawValue
        updatedAt = .now
        completedAt = newStatus == .done ? .now : nil
    }

    func toggleCompleted() {
        moveTo(isCompleted ? .todo : .done)
    }
}

@Model
final class ReminderItem {
    var title: String = ""
    var notes: String = ""
    var remindAt: Date = Date.now
    var repeatRaw: String = ReminderRepeat.none.rawValue
    var isDone: Bool = false
    var createdAt: Date = Date.now
    var notificationID: String?

    var repeatRule: ReminderRepeat {
        get { ReminderRepeat(rawValue: repeatRaw) ?? .none }
        set { repeatRaw = newValue.rawValue }
    }

    init(title: String, notes: String = "", remindAt: Date, repeatRule: ReminderRepeat = .none, isDone: Bool = false) {
        self.title = title
        self.notes = notes
        self.remindAt = remindAt
        self.repeatRaw = repeatRule.rawValue
        self.isDone = isDone
        self.createdAt = .now
        self.notificationID = UUID().uuidString
    }
}

@Model
final class Folder {
    var name: String = ""
    var createdAt: Date = Date.now

    /// العلاقة العكسية اختيارية إلزام الـ CloudKit
    @Relationship(deleteRule: .nullify, inverse: \Note.folder)
    var notes: [Note]? = nil

    init(name: String, createdAt: Date = .now) {
        self.name = name
        self.createdAt = createdAt
    }
}

@Model
final class Note {
    var title: String = ""
    var content: String = ""
    var pinned: Bool = false
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now
    var folder: Folder?

    var displayTitle: String { title.isEmpty ? "بدون عنوان" : title }

    init(title: String = "", content: String = "", pinned: Bool = false, folder: Folder? = nil) {
        self.title = title
        self.content = content
        self.pinned = pinned
        self.createdAt = .now
        self.updatedAt = .now
        self.folder = folder
    }
}

@Model
final class Bookmark {
    var title: String = ""
    var urlString: String = ""
    var categoryRaw: String = BookmarkCategory.reference.rawValue
    var pinned: Bool = false
    var launchCount: Int = 0
    var createdAt: Date = Date.now

    var category: BookmarkCategory {
        get { BookmarkCategory(rawValue: categoryRaw) ?? .reference }
        set { categoryRaw = newValue.rawValue }
    }

    var url: URL? {
        URL(string: urlString.hasPrefix("http") ? urlString : "https://\(urlString)")
    }

    var domain: String {
        URL(string: urlString.hasPrefix("http") ? urlString : "https://\(urlString)")?.host() ?? urlString
    }

    init(title: String, urlString: String, category: BookmarkCategory = .reference, pinned: Bool = false) {
        self.title = title
        self.urlString = urlString
        self.categoryRaw = category.rawValue
        self.pinned = pinned
        self.launchCount = 0
        self.createdAt = .now
    }
}

// MARK: - ترتيب موحد للمهام في كل قوائم التطبيق

enum TaskOrdering {
    /// الترتيب المعتمد: حسب تاريخ الاستحقاق (الأقرب أولًا، وبدونه يذهب لآخر القائمة)
    /// ثم حسب الأولوية (عالية ← متوسطة ← منخفضة ← بدون) ثم الأحدث إنشاءً.
    static func compare(_ a: TaskItem, _ b: TaskItem) -> Bool {
        let da = a.dueDate ?? .distantFuture
        let db = b.dueDate ?? .distantFuture
        if da != db { return da < db }
        if a.priority.sortIndex != b.priority.sortIndex {
            return a.priority.sortIndex < b.priority.sortIndex
        }
        return a.createdAt > b.createdAt
    }

    static func sort(_ tasks: [TaskItem]) -> [TaskItem] {
        tasks.sorted { compare($0, $1) }
    }
}

// MARK: - قيم ثابتة

enum AppConstants {
    /// اسم المجلد الذي تُحفظ فيه الملاحظات السريعة تلقائيًا
    static let quickNoteFolderName = "الملاحظات السريعة"
    static let defaultFolderNames = ["عام", "مشاريع", "عمل", "شخصي", "أفكار"]
}
