import Foundation
import SwiftData
import AppKit
import UniformTypeIdentifiers
import UserNotifications

// MARK: - نماذج النسخ الاحتياطية (JSON)

struct BackupFile: Codable {
    var formatVersion = 1
    var appName = AppInfo.name
    var exportedAt: Date
    var projects: [BackupProject]
    var tasks: [BackupTask]
    var folders: [BackupFolder]
    var notes: [BackupNote]
    var reminders: [BackupReminder]
    var bookmarks: [BackupBookmark]
}

struct BackupProject: Codable {
    var name: String
    var emoji: String
    var createdAt: Date
}

struct BackupTask: Codable {
    var title: String
    var details: String
    var status: String
    var priority: String
    var dueDate: Date?
    var createdAt: Date
    var updatedAt: Date
    var completedAt: Date?
    var projectName: String?
}

struct BackupFolder: Codable {
    var name: String
    var createdAt: Date
}

struct BackupNote: Codable {
    var title: String
    var content: String
    var pinned: Bool
    var createdAt: Date
    var updatedAt: Date
    var folderName: String?
}

struct BackupReminder: Codable {
    var title: String
    var notes: String
    var remindAt: Date
    var repeatRule: String
    var isDone: Bool
    var createdAt: Date
}

struct BackupBookmark: Codable {
    var title: String
    var url: String
    var category: String
    var pinned: Bool
    var launchCount: Int
    var createdAt: Date
}

// MARK: - إدارة النسخ الاحتياطي

enum BackupManager {

    // MARK: بناء صورة البيانات

    static func buildBackup(context: ModelContext) -> BackupFile {
        let projects = (try? context.fetch(FetchDescriptor<Project>(sortBy: [.init(\.createdAt)]))) ?? []
        let tasks = (try? context.fetch(FetchDescriptor<TaskItem>(sortBy: [.init(\.createdAt)]))) ?? []
        let folders = (try? context.fetch(FetchDescriptor<Folder>(sortBy: [.init(\.createdAt)]))) ?? []
        let notes = (try? context.fetch(FetchDescriptor<Note>(sortBy: [.init(\.createdAt)]))) ?? []
        let reminders = (try? context.fetch(FetchDescriptor<ReminderItem>(sortBy: [.init(\.createdAt)]))) ?? []
        let bookmarks = (try? context.fetch(FetchDescriptor<Bookmark>(sortBy: [.init(\.createdAt)]))) ?? []

        return BackupFile(
            exportedAt: .now,
            projects: projects.map {
                BackupProject(name: $0.name, emoji: $0.emoji, createdAt: $0.createdAt)
            },
            tasks: tasks.map {
                BackupTask(
                    title: $0.title,
                    details: $0.details,
                    status: $0.statusRaw,
                    priority: $0.priorityRaw,
                    dueDate: $0.dueDate,
                    createdAt: $0.createdAt,
                    updatedAt: $0.updatedAt,
                    completedAt: $0.completedAt,
                    projectName: $0.project?.name
                )
            },
            folders: folders.map {
                BackupFolder(name: $0.name, createdAt: $0.createdAt)
            },
            notes: notes.map {
                BackupNote(
                    title: $0.title,
                    content: $0.content,
                    pinned: $0.pinned,
                    createdAt: $0.createdAt,
                    updatedAt: $0.updatedAt,
                    folderName: $0.folder?.name
                )
            },
            reminders: reminders.map {
                BackupReminder(
                    title: $0.title,
                    notes: $0.notes,
                    remindAt: $0.remindAt,
                    repeatRule: $0.repeatRaw,
                    isDone: $0.isDone,
                    createdAt: $0.createdAt
                )
            },
            bookmarks: bookmarks.map {
                BackupBookmark(
                    title: $0.title,
                    url: $0.urlString,
                    category: $0.categoryRaw,
                    pinned: $0.pinned,
                    launchCount: $0.launchCount,
                    createdAt: $0.createdAt
                )
            }
        )
    }

    @MainActor
    static func summary(_ backup: BackupFile) -> String {
        var parts: [String] = []
        if !backup.projects.isEmpty { parts.append("\(backup.projects.count) مشاريع") }
        if !backup.tasks.isEmpty { parts.append("\(backup.tasks.count) مهام") }
        if !backup.notes.isEmpty { parts.append("\(backup.notes.count) ملاحظات") }
        if !backup.folders.isEmpty { parts.append("\(backup.folders.count) مجلدات") }
        if !backup.reminders.isEmpty { parts.append("\(backup.reminders.count) تذكيرات") }
        if !backup.bookmarks.isEmpty { parts.append("\(backup.bookmarks.count) علامات") }
        return parts.isEmpty ? "نسخة فارغة (لا بيانات)" : parts.joined(separator: " • ")
    }

    /// وصف مختصر للنسخة المختارة قبل تأكيد الاستيراد
    @MainActor
    static func summaryTextForImport(_ backup: BackupFile?) -> String {
        guard let backup else { return "" }
        return summary(backup)
    }

    // MARK: تصدير

    /// يعرض لوحة حفظ ويدوّن ملف JSON. يعيد رسالة النتيجة (أو الخطأ).
    @MainActor
    static func export(context: ModelContext) -> String? {
        let backup = buildBackup(context: context)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        guard let data = try? encoder.encode(backup) else {
            return "تعذر تجهيز بيانات النسخة الاحتياطية."
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"

        let panel = NSSavePanel()
        panel.title = "حفظ نسخة احتياطية"
        panel.allowedContentTypes = [.json]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = "\(AppInfo.name)-نسخة-\(formatter.string(from: .now)).json"

        guard panel.runModal() == .OK, let url = panel.url else { return nil }

        do {
            try data.write(to: url, options: [.atomic])
            return "تم تصدير نسخة احتياطية كاملة ✓\n" + summary(backup)
        } catch {
            return "تعذر حفظ الملف: \(error.localizedDescription)"
        }
    }

    // MARK: اختيار ملف للاستيراد

    @MainActor
    static func pickBackupFile() -> BackupFile? {
        let panel = NSOpenPanel()
        panel.title = "استيراد نسخة احتياطية"
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else { return nil }

        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(BackupFile.self, from: data)
    }

    // MARK: استيراد (استبدال كامل)

    /// يستبدل كل بيانات التطبيق بمحتوى النسخة، ويعيد رسالة النتيجة.
    @MainActor
    static func replaceAllData(with backup: BackupFile, in context: ModelContext) -> String {
        // إيقاف كل إشعارات النسخة السابقة
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()

        // تفريغ كل النماذج
        try? context.delete(model: TaskItem.self)
        try? context.delete(model: Project.self)
        try? context.delete(model: Note.self)
        try? context.delete(model: ReminderItem.self)
        try? context.delete(model: Bookmark.self)
        try? context.delete(model: Folder.self)
        try? context.save()

        // 1) المجلدات (مع دعم الأسماء المتكررة — أول ظهور هو المرجع)
        var folderIndex: [String: Folder] = [:]
        for folder in backup.folders {
            let model = Folder(name: folder.name, createdAt: folder.createdAt)
            context.insert(model)
            if folderIndex[folder.name] == nil { folderIndex[folder.name] = model }
        }

        // 2) المشاريع
        var projectIndex: [String: Project] = [:]
        for project in backup.projects {
            let model = Project(name: project.name, emoji: project.emoji, createdAt: project.createdAt)
            context.insert(model)
            if projectIndex[project.name] == nil { projectIndex[project.name] = model }
        }

        // 3) المهام
        for task in backup.tasks {
            let model = TaskItem(
                title: task.title,
                details: task.details,
                status: TaskStatus(rawValue: task.status) ?? .todo,
                priority: TaskPriority(rawValue: task.priority) ?? .none,
                dueDate: task.dueDate,
                project: task.projectName.flatMap { projectIndex[$0] }
            )
            model.createdAt = task.createdAt
            model.updatedAt = task.updatedAt
            model.completedAt = task.completedAt
            context.insert(model)
        }

        // 4) الملاحظات
        for note in backup.notes {
            let model = Note(
                title: note.title,
                content: note.content,
                pinned: note.pinned,
                folder: note.folderName.flatMap { folderIndex[$0] }
            )
            model.createdAt = note.createdAt
            model.updatedAt = note.updatedAt
            context.insert(model)
        }

        // 5) التذكيرات (مع جدولة إشعاراتها مجددًا)
        var reminderModels: [ReminderItem] = []
        for reminder in backup.reminders {
            let model = ReminderItem(
                title: reminder.title,
                notes: reminder.notes,
                remindAt: reminder.remindAt,
                repeatRule: ReminderRepeat(rawValue: reminder.repeatRule) ?? .none,
                isDone: reminder.isDone
            )
            model.createdAt = reminder.createdAt
            context.insert(model)
            reminderModels.append(model)
        }

        // 6) العلامات المرجعية
        for bookmark in backup.bookmarks {
            let model = Bookmark(
                title: bookmark.title,
                urlString: bookmark.url,
                category: BookmarkCategory(rawValue: bookmark.category) ?? .reference,
                pinned: bookmark.pinned
            )
            model.launchCount = bookmark.launchCount
            model.createdAt = bookmark.createdAt
            context.insert(model)
        }

        try? context.save()

        // جدولة إشعارات التذكيرات غير المنجزة المستقبلية
        for reminder in reminderModels where !reminder.isDone && reminder.remindAt > .now {
            NotificationScheduler.schedule(reminder)
        }

        return "تم استيراد النسخة الاحتياطية واستبدال البيانات ✓\n" + summary(backup)
    }
}
