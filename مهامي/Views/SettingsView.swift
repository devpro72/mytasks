import SwiftUI
import SwiftData

// MARK: - صفحة الإعدادات داخل التطبيق (تفتح نافذة الإعدادات)

struct SettingsMainView: View {
    @Environment(\.openSettings) private var openSettings
    @Environment(\.modelContext) private var context

    @State private var pendingImport: BackupFile?
    @State private var showImportConfirmation = false
    @State private var resultMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("الإعدادات")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.appText)
                    Text("خصّص مظهر التطبيق وتفضيلاتك العامة.")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.appMuted)
                }

                HStack(spacing: 12) {
                    settingsCard(icon: "drop.circle", title: "المظهر", subtitle: "اختر نمط الألوان: تلقائي، فاتح دافئ، أو داكن") {
                        openSettings()
                    }
                    settingsCard(icon: "123.rectangle", title: "الأرقام", subtitle: "أرقام غربية 1234567890 مفعّلة دائمًا ولا يمكن تغييرها", action: nil)
                    settingsCard(icon: "arrow.uturn.right.circle", title: "الاتجاه", subtitle: "الواجهة كاملة من اليمين إلى اليسار بالعربية", action: nil)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("تخزين البيانات")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.appText)

                    HStack(spacing: 12) {
                        settingsCard(
                            icon: AppSchema.usesiCloud ? "icloud.fill" : "internaldrive.fill",
                            title: AppSchema.usesiCloud ? "التخزين السحابي مفعّل" : "التخزين محلي",
                            subtitle: AppSchema.usesiCloud
                                ? "مزامنة تلقائية عبر iCloud بين أجهزتك (iCloud.com.devpro.mytasks)"
                                : "البيانات محفوظة على هذا الجهاز فقط — يتطلب تسجيل الدخول إلى iCloud للتفعيل",
                            action: nil
                        )
                        settingsCard(
                            icon: "shield.fill",
                            title: "أمان البيانات",
                            subtitle: "تُنقل البيانات مشفّرة عبر خاصية CloudKit الخاص بالجهاز",
                            action: nil
                        )
                    }
                }
                .padding(.top, 4)

                VStack(alignment: .leading, spacing: 10) {
                    Text("النسخ الاحتياطي")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.appText)

                    HStack(spacing: 12) {
                        settingsCard(icon: "square.and.arrow.up",
                                     title: "تصدير نسخة احتياطية",
                                     subtitle: "حفظ كل بياناتك في ملف JSON") {
                            resultMessage = BackupManager.export(context: context)
                        }
                        settingsCard(icon: "square.and.arrow.down",
                                     title: "استيراد نسخة…",
                                     subtitle: "استبدال البيانات الحالية بمحتوى نسخة سابقة") {
                            if let backup = BackupManager.pickBackupFile() {
                                pendingImport = backup
                                showImportConfirmation = true
                            }
                        }
                    }
                }
                .padding(.top, 4)

                VStack(alignment: .leading, spacing: 10) {
                    Text("معلومات سريعة")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.appText)

                    HStack(spacing: 12) {
                        StatCard(icon: "hand.point.up.left",
                                 tint: Color.appAccent,
                                 value: "زر",
                                 title: "زر الملاحظة السريعة",
                                 subtitle: "في أسفل الشريط الجانبي يُظهر/يُخفي النافذة العائمة")
                        StatCard(icon: "keyboard",
                                 tint: Color(hex: 0x5B7DA3),
                                 value: "⌘S",
                                 title: "حفظ سريع",
                                 subtitle: "حفظ الملاحظة السريعة من نافذتها")
                    }
                }
            }
            .padding(.horizontal, 26)
            .padding(.top, 20)
            .padding(.bottom, 30)
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .background(Color.appBackground)
        .navigationTitle("الإعدادات")
        .alert("استيراد نسخة احتياطية؟", isPresented: $showImportConfirmation) {
            Button("استبدال البيانات", role: .destructive, action: performImport)
            Button("إلغاء", role: .cancel) { pendingImport = nil }
        } message: {
            Text("سيتم استبدال بياناتك الحالية بالكامل بمحتوى النسخة: " + BackupManager.summaryTextForImport(pendingImport))
        }
        .alert(resultMessage ?? "", isPresented: Binding(
            get: { resultMessage != nil },
            set: { if !$0 { resultMessage = nil } }
        )) {
            Button("تم", role: .cancel) {}
        }
    }

    private func performImport() {
        guard let backup = pendingImport else { return }
        pendingImport = nil
        resultMessage = BackupManager.replaceAllData(with: backup, in: context)
    }

    private func settingsCard(icon: String, title: String, subtitle: String, action: (() -> Void)? = nil) -> some View {
        Button {
            action?()
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(Color.appAccentSoft)
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.appAccent)
                }
                .frame(width: 32, height: 32)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.appText)
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(Color.appMuted)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                if action != nil {
                    Image(systemName: "chevron.forward")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.appMuted)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .surface()
        }
        .buttonStyle(.press)
        .disabled(action == nil)
    }
}

// MARK: - نافذة الإعدادات (بدون Form — لا تجمّد ولا تكدّس)

struct SettingsView: View {
    @AppStorage("appearanceMode") private var appearanceMode = 0
    @Environment(\.modelContext) private var context

    @Query private var tasks: [TaskItem]
    @Query private var projects: [Project]
    @Query private var notes: [Note]
    @Query private var folders: [Folder]
    @Query private var reminders: [ReminderItem]
    @Query private var bookmarks: [Bookmark]

    @State private var showResetConfirmation = false
    @State private var pendingImport: BackupFile?
    @State private var showImportConfirmation = false
    @State private var resultMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                appearanceSection
                basicsSection
                dataSection
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .frame(width: 560)
        .frame(minHeight: 380, idealHeight: 480, maxHeight: 600)
        .background(Color.appBackground)
        .alert("حذف جميع البيانات؟", isPresented: $showResetConfirmation) {
            Button("حذف نهائيًا", role: .destructive, action: deleteAllData)
            Button("إلغاء", role: .cancel) {}
        } message: {
            Text("سيتم حذف جميع المهام والمشاريع والملاحظات والتذكيرات والعلامات نهائيًا. لا يمكن الرجوع عن ذلك.")
        }
        .alert("استيراد نسخة احتياطية؟", isPresented: $showImportConfirmation) {
            Button("استبدال البيانات", role: .destructive, action: performImport)
            Button("إلغاء", role: .cancel) { pendingImport = nil }
        } message: {
            Text("سيتم استبدال بياناتك الحالية بالكامل بمحتوى النسخة: " + BackupManager.summaryTextForImport(pendingImport))
        }
        .alert(resultMessage ?? "", isPresented: Binding(
            get: { resultMessage != nil },
            set: { if !$0 { resultMessage = nil } }
        )) {
            Button("تم", role: .cancel) {}
        }
    }

    // MARK: المظهر

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle(icon: "drop.circle", title: "المظهر", subtitle: "نمط ألوان ثابت في كل التطبيق")

            HStack(spacing: 12) {
                appearanceCard(icon: "circle.lefthalf.filled", title: "تلقائي", subtitle: "بحسب النظام", mode: 0)
                appearanceCard(icon: "sun.max.fill", title: "فاتح دافئ", subtitle: "كريمي دافئ", mode: 1)
                appearanceCard(icon: "moon.fill", title: "داكن", subtitle: "فحمي هادئ", mode: 2)
            }
        }
    }

    private func appearanceCard(icon: String, title: String, subtitle: String, mode: Int) -> some View {
        let isSelected = appearanceMode == mode
        return Button {
            appearanceMode = mode
        } label: {
            VStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.appAccentSoft)
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(Color.appAccent)
                }
                .frame(width: 42, height: 42)

                VStack(spacing: 3) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.appText)
                    Text(subtitle)
                        .font(.system(size: 10))
                        .foregroundStyle(Color.appMuted)
                }

                HStack(spacing: 6) {
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.appAccent)
                    }
                    Text(isSelected ? "مُختار" : "اختيار")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(isSelected ? Color.appAccent : Color.appMuted)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity)
            .surface()
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(isSelected ? Color.appAccent : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.press)
    }

    // MARK: الأساسيات

    private var basicsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle(icon: "123.rectangle", title: "الأساسيات", subtitle: "خصائص ثابتة في التطبيق")

            VStack(spacing: 8) {
                infoRow(
                    icon: AppSchema.usesiCloud ? "icloud.fill" : "internaldrive.fill",
                    title: AppSchema.usesiCloud ? "التخزين: iCloud — مزامنة تلقائية بين أجهزتك" : "التخزين: محلي على هذا الجهاز",
                    subtitle: AppSchema.usesiCloud ? "البيانات تُرفع إلى مجد CloudKit الخاص بالتطبيق (iCloud.com.devpro.mytasks)." : "يلزم تسجيل الدخول إلى iCloud لتفعيل المزامنة."
                )
                infoRow(icon: "number.square.fill", title: "الأرقام الغربية دائمًا: 1234567890", subtitle: "لا يُستخدم الرقم الهندي (١٢٣) في أي مكان، بما في ذلك التواريخ.")
                infoRow(icon: "textformat", title: "اللغة: العربية — الاتجاه: من اليمين إلى اليسار", subtitle: "كل الشاشات والنوافذ منبثقة تتبع اتجاه RTL.")
                infoRow(icon: "bolt.fill", title: "الملاحظة السريعة", subtitle: "احفظ سريعًا بـ ⌘S من النافذة العائمة.")
            }
        }
    }

    private func infoRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Color.appAccentSoft)
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.appAccent)
            }
            .frame(width: 30, height: 30)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(Color.appText)
                Text(subtitle)
                    .font(.system(size: 10.5))
                    .foregroundStyle(Color.appMuted)
            }
            Spacer()
        }
        .padding(12)
        .surface(cornerRadius: 10)
    }

    // MARK: البيانات

    private var dataSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle(icon: "internaldrive", title: "البيانات", subtitle: "كل شيء محفوظ محليًا على جهازك")

            HStack(spacing: 14) {
                dataCount("مهام", tasks.count)
                dataCount("مشاريع", projects.count)
                dataCount("ملاحظات", notes.count)
                dataCount("مجلدات", folders.count)
                dataCount("تذكيرات", reminders.count)
                dataCount("علامات", bookmarks.count)
                Spacer()
            }
            .padding(12)
            .surface(cornerRadius: 10)

            HStack(spacing: 10) {
                Button {
                    if let message = BackupManager.export(context: context) {
                        resultMessage = message
                    }
                } label: {
                    Label("تصدير نسخة احتياطية…", systemImage: "square.and.arrow.up")
                        .font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.appAccent)

                Button {
                    if let backup = BackupManager.pickBackupFile() {
                        pendingImport = backup
                        showImportConfirmation = true
                    }
                } label: {
                    Label("استيراد نسخة…", systemImage: "square.and.arrow.down")
                        .font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(.bordered)
            }

            Button(role: .destructive) {
                showResetConfirmation = true
            } label: {
                Label("حذف جميع البيانات...", systemImage: "trash")
                    .font(.system(size: 12, weight: .semibold))
            }
            .buttonStyle(.bordered)
        }
    }

    private func performImport() {
        guard let backup = pendingImport else { return }
        pendingImport = nil
        resultMessage = BackupManager.replaceAllData(with: backup, in: context)
    }

    private func dataCount(_ label: String, _ count: Int) -> some View {
        VStack(spacing: 4) {
            Text("\(count)")
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(Color.appText)
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(Color.appMuted)
        }
    }

    private func sectionTitle(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.appAccent)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.appText)
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.appMuted)
            }
        }
    }

    private func deleteAllData() {
        try? context.delete(model: TaskItem.self)
        try? context.delete(model: Project.self)
        try? context.delete(model: Note.self)
        try? context.delete(model: ReminderItem.self)
        try? context.delete(model: Bookmark.self)
        try? context.delete(model: Folder.self)
        try? context.save()
    }
}

// MARK: - حول التطبيق

struct AboutView: View {
    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.appAccentSoft)
                Image(systemName: "checklist")
                    .font(.system(size: 42, weight: .medium))
                    .foregroundStyle(Color.appAccent)
            }
            .frame(width: 88, height: 88)

            VStack(spacing: 6) {
                Text(AppInfo.name)
                    .font(.system(size: 27, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.appText)
                Text("الإصدار \(AppInfo.version)")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.appMuted)
                Text(AppInfo.subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.appMuted)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 6) {
                aboutRow(icon: "rectangle.split.3x1", text: "لوحة كانبان لإدارة المهام مع مشاريع وأولويات")
                aboutRow(icon: "calendar", text: "تقويم شهري عربي يبدأ بالسبت")
                aboutRow(icon: "bell", text: "تذكيرات مفعّلة عبر إشعارات النظام")
                aboutRow(icon: "note.text", text: "ملاحظات بالمجلدات مع حفظ تلقائي")
                aboutRow(icon: "bolt.fill", text: "نافذة ملاحظة سريعة عائمة تُظهر وتُخفى بضغطة زر")
                aboutRow(icon: "123.rectangle", text: "أرقام غربية 1234567890 واتجاه كامل من اليمين لليسار")
            }
            .padding(.horizontal, 30)

            Spacer()
        }
        .padding(26)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appBackground)
        .navigationTitle("حول التطبيق")
    }

    private func aboutRow(icon: String, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.appAccent)
                .frame(width: 24)
            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(Color.appText)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .surface()
    }
}
