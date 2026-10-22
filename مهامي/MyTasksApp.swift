import SwiftUI
import SwiftData
import os

@main
struct MyTasksApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .frame(minWidth: 1000, minHeight: 640)
                .applyAppearance()
                .environment(\.layoutDirection, .rightToLeft)
                .environment(\.locale, AppLocale.locale)
        }
        .modelContainer(AppSchema.container)
        .defaultSize(width: 1200, height: 650)
        .commands {
            QuickNoteCommands()
        }

        Window("ملاحظة سريعة", id: "quick-note") {
            QuickNoteView()
                .applyAppearance()
                .forceRTL()
                .environment(\.locale, AppLocale.locale)
        }
        .modelContainer(AppSchema.container)
        .windowResizability(.contentSize)

        Settings {
            SettingsView()
                .applyAppearance()
                .environment(\.layoutDirection, .rightToLeft)
                .environment(\.locale, AppLocale.locale)
        }
        .modelContainer(AppSchema.container)
    }
}

// MARK: - أمر قائمة: فتح الملاحظة السريعة بـ ⌘O من أي نافذة في التطبيق

struct QuickNoteCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandMenu("أدوات") {
            Button("فتح الملاحظة السريعة") {
                openWindow(id: "quick-note")
            }
            .keyboardShortcut("o", modifiers: .command)
        }
    }
}

// MARK: - مخطط البيانات (حاوية واحدة مشتركة لكل النوافذ — مع مزامنة iCloud إن أمكن)

enum AppSchema {
    static let models: [any PersistentModel.Type] = [
        Project.self,
        TaskItem.self,
        ReminderItem.self,
        Note.self,
        Folder.self,
        Bookmark.self
    ]

    /// هل تم تفعيل المزامنة السحابية في هذه الجلسة؟
    static let usesiCloud: Bool = {
        guard let configuration = container.configurations.first else { return false }
        // وصف النمط: CloudKitDatabase(_automatic: true/false, _none: true/false, _privateDBName: …)
        return !String(describing: configuration.cloudKitDatabase).contains("_none: true")
    }()

    /// مسار المخزن: داخل مجلد خاص بالتطبيق (يملكه دائمًا ولا تمنعه النوافذ الحماية)
    static let storeURL: URL = {
        let base = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support", isDirectory: true)
            .appendingPathComponent("com.devpro.mytasks", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appendingPathComponent("default.store")
    }()

    /// نقل المخزن القديم (الملف المباشر في Application Support) إلى المجلد المخصص
    private static func ensureStoreLocation() {
        let fm = FileManager.default
        let legacy = storeURL.deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("default.store")
        guard !fm.fileExists(atPath: storeURL.path), fm.fileExists(atPath: legacy.path) else { return }
        do {
            try fm.moveItem(at: legacy, to: storeURL)
            for ext in ["-wal", "-shm", "-journal"] {
                let from = legacy.path + ext
                if fm.fileExists(atPath: from) { try? fm.moveItem(atPath: from, toPath: storeURL.path + ext) }
            }
            migrationLog.info("تم نقل المخزن إلى \(storeURL.path, privacy: .public)")
        } catch {
            migrationLog.error("تعذر نقل المخزن: \(String(describing: error), privacy: .public)")
        }
    }

    /// حاوية واحدة للنوافذ كلها. مع iCloud يرتبط التخزين بـ CloudKit تلقائيًا،
    /// وإن تعذر ذلك (بلا تسجيل دخول أو صلاحيات) نتراجع للمخزن المحلي بأمان.
    static let container: ModelContainer = {
        let schema = Schema(models)
        ensureStoreLocation()
        let iCloudSignedIn = FileManager.default.ubiquityIdentityToken != nil

        if iCloudSignedIn {
            if let cloud = try? ModelContainer(
                for: schema,
                configurations: [ModelConfiguration(schema: schema, url: storeURL, cloudKitDatabase: .automatic)]
            ) {
                return cloud
            }
            // تعذر ربط iCloud — نتراجع للمحلي بهدوء
        }

        do {
            return try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, url: storeURL, cloudKitDatabase: .none)])
        } catch {
            do {
                return try ModelContainer(for: schema, configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
            } catch {
                fatalError("فشل تهيئة قاعدة البيانات: \(error)")
            }
        }
    }()

    /// ترحيل بيانات المخزن القديم (default.store) إلى الحاوية الجديدة عند أول تشغيل
    static let migrationLog = Logger(subsystem: "com.devpro.mytasks", category: "migration")

    @MainActor
    static func migrateLegacyStoreIfNeeded(context: ModelContext) {
        let fm = FileManager.default
        // المسار القديم: ملف مباشر في مجلد Application Support العام (ترحيل من الإصدارات الأولى)
        let appSupport = storeURL.deletingLastPathComponent()   // …/Application Support/com.devpro.mytasks
        let legacyURL = appSupport.deletingLastPathComponent().appendingPathComponent("default.store")
        let flagURL = appSupport.appendingPathComponent("iCloud-migration-done.flag")

        guard fm.fileExists(atPath: legacyURL.path) else {
            migrationLog.info("لا يوجد مخزن قديم في \(legacyURL.path, privacy: .public)")
            return
        }
        migrationLog.info("بدء ترحيل المخزن القديم...")

        // هل الحاوية الحالية هي نفس الملف القديم؟ لا حاجة للترحيل
        if let currentURL = container.configurations.first?.url,
           currentURL.standardizedFileURL == legacyURL.standardizedFileURL {
            try? fm.createFile(atPath: flagURL.path, contents: nil)
            migrationLog.info("الحاوية تشير لنفس الملف القديم — لا ترحيل")
            return
        }

        // مهاجرناه سابقاً؟ أرشف الملف القديم واخرج
        let archiveURL = appSupport.appendingPathComponent("default.store.pre-iCloud")
        if fm.fileExists(atPath: flagURL.path) {
            migrationLog.info("تم الترحيل سابقاً — أرشفة الملف القديم فقط")
            if !fm.fileExists(atPath: archiveURL.path) {
                try? fm.moveItem(at: legacyURL, to: archiveURL)
            }
            return
        }

        do {
            let legacyConfig = ModelConfiguration(
                schema: Schema(models),
                url: legacyURL,
                cloudKitDatabase: .none
            )
            let legacyContainer = try ModelContainer(for: Schema(models), configurations: [legacyConfig])
            let legacyContext = ModelContext(legacyContainer)

            let backup = BackupManager.buildBackup(context: legacyContext)
            _ = BackupManager.replaceAllData(with: backup, in: context)
            migrationLog.info("تم الترحيل ✓ ملاحظات=\(backup.notes.count) مهام=\(backup.tasks.count) مشاريع=\(backup.projects.count)")

            try fm.createFile(atPath: flagURL.path, contents: nil)
            if !fm.fileExists(atPath: archiveURL.path) {
                try? fm.moveItem(at: legacyURL, to: archiveURL)
            }
        } catch {
            migrationLog.error("تعذر ترحيل النسخة القديمة: \(String(describing: error), privacy: .public)")
            // نترك كل شيء كما هو
        }
    }
}
