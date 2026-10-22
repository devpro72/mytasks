import SwiftUI
import SwiftData
import AppKit

/// نافذة عائمة صغيرة لإضافة ملاحظة سريعة تُحفظ في «ملاحظاتي».
struct QuickNoteView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Folder.createdAt) private var folders: [Folder]

    @State private var title = ""
    @State private var text = ""
    @State private var folder: Folder?
    @State private var justSaved = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "bolt.circle.fill")
                    .foregroundStyle(Color.appAccent)
                Text("ملاحظة سريعة")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                if justSaved {
                    Label("حُفظت", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color(hex: 0x3E7C4F))
                        .transition(.opacity)
                }
                Button {
                    WindowManager.shared.hideQuickNote()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(Color.appMuted)
                }
                .buttonStyle(.press)
                .help("إخفاء النافذة")
            }

            HStack {
                TextField("العنوان (اختياري)...", text: $title)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, weight: .semibold))
                    .fixedSize(horizontal: true, vertical: false)
                Spacer()
            }
            .padding(8)
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.appField))

            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text("اكتب ملاحظتك أو قائمتك هنا...")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.appMuted)
                        .padding(.horizontal, 9)
                        .padding(.top, 9)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $text)
                    .font(.system(size: 13))
                    .scrollContentBackground(.hidden)
                    .padding(6)
            }
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.appField))
            .frame(minHeight: 120, maxHeight: .infinity)

            HStack(spacing: 8) {
                Menu {
                    Button("بدون مجلد") { folder = nil }
                    ForEach(folders) { f in
                        Button(f.name) { folder = f }
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "folder")
                            .font(.system(size: 10))
                        Text(folder?.name ?? "المجلد")
                            .font(.system(size: 11, weight: .medium))
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Color.appAccentSoft))
                    .foregroundStyle(Color.appAccent)
                }
                .menuStyle(.borderlessButton)

                Spacer()

                Button {
                    saveNote()
                } label: {
                    Label("حفظ إلى الملاحظات", systemImage: "square.and.arrow.down")
                        .font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.appAccent)
                .keyboardShortcut("s", modifiers: .command)
                .disabled(title.isBlank && text.isBlank)
            }
        }
        .padding(14)
      //  .frame(width: 330, height: 320)
        .frame(width: 330, height: 280)
        .background(Color.appBackground)
        .forceRTL()
        .onAppear {
            DispatchQueue.main.async {
                WindowManager.shared.registerQuickNote(NSApp.keyWindow)
            }
            folder = folders.first { $0.name == AppConstants.quickNoteFolderName }
        }
        .onDisappear {
            // حفظ تلقائي: ما دُوّن ولم يُحفظ يُحفظ عند إغلاق/إخفاء النافذة
            if !title.isBlank || !text.isBlank {
                saveNote(silent: true)
            }
            WindowManager.shared.unregisterQuickNote()
        }
    }

    private func saveNote(silent: Bool = false) {
        // ضمان وجود المجلد الافتراضي للملاحظات السريعة
        var target = folder
        if target == nil {
            target = folders.first { $0.name == AppConstants.quickNoteFolderName }
        }
        if target == nil {
            let created = Folder(name: AppConstants.quickNoteFolderName)
            context.insert(created)
            target = created
        }

        let fallbackTitle = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: "\n")
            .first ?? ""

        let note = Note(
            title: title.isBlank ? fallbackTitle : title,
            content: text,
            folder: target
        )
        context.insert(note)
        try? context.save()

        title = ""
        text = ""
        if !silent {
            withAnimation {
                justSaved = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                justSaved = false
            }
        }
    }
}
