import SwiftUI
import SwiftData
import AppKit

// MARK: - وحدة ملاحظاتي (Scratchpad)

struct ScratchpadView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Folder.createdAt) private var folders: [Folder]
    @Query(sort: \Note.updatedAt, order: .reverse) private var allNotes: [Note]

    @State private var selectedFolder: Folder?
    @State private var selectedNote: Note?
    @State private var searchText = ""
    @State private var showNewFolderPopover = false
    @State private var newFolderName = ""

    var body: some View {
        HStack(spacing: 0) {
            foldersPane
                .frame(width: 190)
            Divider()
                .overlay(Color.appBorder)
            notesPane
                .frame(width: 290)
            Divider()
                .overlay(Color.appBorder)
            editorPane
        }
        .background(Color.appBackground)
        .navigationTitle("ملاحظاتي")
    }

    // MARK: اللوحة الأولى — المجلدات

    private var foldersPane: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("المجلدات")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.appMuted)
                Spacer()
                Button {
                    newFolderName = ""
                    showNewFolderPopover = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.appMuted)
                }
                .buttonStyle(.press)
                .popover(isPresented: $showNewFolderPopover) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("مجلد جديد")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                        TextField("اسم المجلد", text: $newFolderName)
                            .textFieldStyle(.roundedBorder)
                        HStack {
                            Spacer()
                            Button("إضافة") { addFolder() }
                                .keyboardShortcut(.defaultAction)
                                .disabled(newFolderName.isBlank)
                        }
                    }
                    .padding(14)
                    .frame(width: 220)
                }
            }
            .padding(.horizontal, 10)
            .padding(.top, 10)
            .padding(.bottom, 4)

            folderRow(icon: "tray.full", title: "كل الملاحظات", count: allNotes.count, isSelected: selectedFolder == nil) {
                selectedFolder = nil
                selectedNote = nil
            }

            Divider().overlay(Color.appBorder).padding(.vertical, 4)

            ScrollView {
                VStack(spacing: 2) {
                    ForEach(folders) { folder in
                        folderRow(
                            icon: "folder",
                            title: folder.name,
                            count: folder.notes?.count ?? 0,
                            isSelected: selectedFolder == folder
                        ) {
                            selectedFolder = folder
                            selectedNote = nil
                        }
                        .contextMenu {
                            Button("حذف المجلد", role: .destructive) { deleteFolder(folder) }
                        }
                    }
                }
            }

            Divider().overlay(Color.appBorder).padding(.top, 4)
        }
        .padding(.bottom, 8)
    }

    private func folderRow(icon: String, title: String, count: Int, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(isSelected ? Color.white : Color.appMuted)
                Text(title)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .lineLimit(1)
                Spacer()
                Text("\(count)")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.white.opacity(0.85) : Color.appMuted)
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(isSelected ? Palette.highlight : Color.clear)
            )
            .foregroundStyle(isSelected ? Color.white : Color.appText)
        }
        .buttonStyle(.press)
        .padding(.horizontal, 6)
    }

    private func addFolder() {
        let name = newFolderName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isBlank else { return }
        let folder = Folder(name: name)
        context.insert(folder)
        newFolderName = ""
        showNewFolderPopover = false
    }

    private func deleteFolder(_ folder: Folder) {
        context.delete(folder)
        if selectedFolder == folder {
            selectedFolder = nil
        }
    }

    // MARK: اللوحة الثانية — قائمة الملاحظات

    private var visibleNotes: [Note] {
        var notes = allNotes
        if let folder = selectedFolder {
            notes = notes.filter { $0.folder == folder }
        }
        if !searchText.isBlank {
            notes = notes.filter {
                $0.title.localizedStandardContains(searchText) ||
                $0.content.localizedStandardContains(searchText)
            }
        }
        return notes.sorted {
            if $0.pinned != $1.pinned { return $0.pinned }
            if $0.updatedAt != $1.updatedAt { return $0.updatedAt > $1.updatedAt }
            return $0.createdAt > $1.createdAt
        }
    }

    private var listTitle: String {
        selectedFolder?.name ?? "كل الملاحظات"
    }

    private var notesPane: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Text(listTitle)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .lineLimit(1)
                Text("\(visibleNotes.count)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.appMuted)
                Spacer()
                Button {
                    createNote()
                } label: {
                    Label("ملاحظة جديدة", systemImage: "plus")
                        .font(.system(size: 11, weight: .semibold))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(Color.appAccent)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.appMuted)
                TextField("بحث...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(Color.appField))
            .padding(.horizontal, 10)
            .padding(.bottom, 8)

            if visibleNotes.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "note.text")
                        .font(.system(size: 24))
                        .foregroundStyle(Color.appMuted.opacity(0.5))
                    Text("لا توجد ملاحظات")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.appMuted)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(visibleNotes) { note in
                            NoteCard(
                                note: note,
                                isSelected: selectedNote == note,
                                action: { selectedNote = note },
                                onDelete: { deleteNote(note) }
                            )
                            .onTapGesture(count: 2) { selectedNote = note }
                            .simultaneousGesture(
                                TapGesture(count: 2).onEnded {
                                    selectedNote = note
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 10)
                }
            }
        }
    }

    // MARK: اللوحة الثالثة — المحرر

    @ViewBuilder
    private var editorPane: some View {
        if let note = selectedNote {
            NoteEditor(note: note, onDelete: {
                context.delete(note)
                try? context.save()
                selectedNote = nil
            })
            .id(note.persistentModelID)
        } else {
            VStack(spacing: 10) {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 30))
                    .foregroundStyle(Color.appMuted.opacity(0.5))
                Text("اختر ملاحظة أو أنشئ ملاحظة جديدة")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.appMuted)
                Button {
                    createNote()
                } label: {
                    Label("ملاحظة جديدة", systemImage: "plus")
                        .font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.appAccent)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func createNote() {
        let note = Note(folder: selectedFolder)
        context.insert(note)
        try? context.save()
        selectedNote = note
    }

    private func deleteNote(_ note: Note) {
        context.delete(note)
        try? context.save()
        if selectedNote == note {
            selectedNote = nil
        }
    }
}

// MARK: - بطاقة ملاحظة

struct NoteCard: View {
    @Environment(\.modelContext) private var context
    let note: Note
    let isSelected: Bool
    let action: () -> Void
    let onDelete: () -> Void

    private var preview: String {
        let text = note.content.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.split(separator: "\n").first.map(String.init) ?? "لا يوجد نص إضافي"
    }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.appMuted)
                    Text(note.displayTitle)
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(Color.appText)
                        .lineLimit(1)
                    if note.pinned {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(Color.appAccent)
                    }
                    Spacer()
                }

                if let folder = note.folder {
                    ChipView(label: folder.name, icon: "folder", color: Color.appAccent)
                }

                Text(preview)
                    .font(.system(size: 11.5))
                    .foregroundStyle(Color.appMuted)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                HStack {
                    Text(Fmt.relativeTime(note.updatedAt))
                        .font(.system(size: 10))
                        .foregroundStyle(Color.appMuted)
                    Spacer()
                    Text("\(note.content.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count) كلمة")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.appMuted.opacity(0.8))
                }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? Color.appAccentSoft : Color.appCard)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(isSelected ? Color.appAccent : Color.appBorder, lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .buttonStyle(.press)
        .contextMenu {
            Button(note.pinned ? "إلغاء التثبيت" : "تثبيت") {
                note.pinned.toggle()
                try? context.save()
            }
            Divider()
            Button("حذف الملاحظة", role: .destructive) {
                onDelete()
            }
        }
    }
}

// MARK: - محرر الملاحظة (حفظ تلقائي)

struct NoteEditor: View {
    @Bindable var note: Note
    let onDelete: () -> Void

    @Environment(\.modelContext) private var context
    @Query(sort: \Folder.createdAt) private var folders: [Folder]

    @State private var showedSavedAt = false
    @State private var debounceTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider().overlay(Color.appBorder)
            editor
            Divider().overlay(Color.appBorder)
            statusBar
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var toolbar: some View {
        HStack(spacing: 10) {
            Menu {
                Button("بدون مجلد") { note.folder = nil; touch() }
                ForEach(folders) { folder in
                    Button(folder.name) {
                        note.folder = folder
                        touch()
                    }
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "folder")
                        .font(.system(size: 10))
                    Text(note.folder?.name ?? "بدون مجلد")
                        .font(.system(size: 11, weight: .medium))
                        .lineLimit(1)
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(Capsule().fill(Color.appAccentSoft))
                .foregroundStyle(Color.appAccent)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()

            Spacer()

            Button {
                note.pinned.toggle()
                touch()
            } label: {
                Image(systemName: note.pinned ? "pin.fill" : "pin")
                    .font(.system(size: 12))
                    .foregroundStyle(note.pinned ? Color.appAccent : Color.appMuted)
            }
            .buttonStyle(.press)
            .help(note.pinned ? "إلغاء التثبيت" : "تثبيت الملاحظة")

            Button {
                copyContent()
            } label: {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.appMuted)
            }
            .buttonStyle(.press)
            .help("نسخ المحتوى")

            Button {
                onDelete()
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 12))
                    .foregroundStyle(Color(hex: 0xC25450))
            }
            .buttonStyle(.press)
            .help("حذف الملاحظة")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var editor: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    TextField("عنوان الملاحظة", text: $note.title, prompt: Text("بدون عنوان"))
                        .textFieldStyle(.plain)
                        .font(.system(size: 21, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.appText)
                        .fixedSize(horizontal: true, vertical: false)
                    Spacer()
                }

                ZStack(alignment: .topLeading) {
                    if note.content.isEmpty {
                        Text("ابدأ الكتابة هنا... تُحفظ الملاحظة تلقائيًا")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.appMuted.opacity(0.7))
                            .padding(.top, 8)
                            .allowsHitTesting(false)
                    }
                    TextEditor(text: $note.content)
                        .font(.system(size: 14))
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 380)
                        .background(Color.clear)
                }
            }
            .padding(.horizontal, 22)
            .padding(.top, 16)
            .padding(.bottom, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onChange(of: note.content) { scheduleSave() }
        .onChange(of: note.title) { scheduleSave() }
        .onDisappear {
            debounceTask?.cancel()
        }
    }

    private var statusBar: some View {
        HStack(spacing: 10) {
            if let folder = note.folder {
                HStack(spacing: 4) {
                    Image(systemName: "folder")
                        .font(.system(size: 9))
                    Text(folder.name)
                        .font(.system(size: 10, weight: .semibold))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Capsule().fill(Color.appAccentSoft))
                .foregroundStyle(Color.appAccent)
                .fixedSize()
                .lineLimit(1)
            }

            Text("آخر تحديث: " + Fmt.relativeTime(note.updatedAt))
                .font(.system(size: 10))
                .foregroundStyle(Color.appMuted)
                .lineLimit(1)
                .fixedSize()

            Spacer(minLength: 6)

            Text("\(wordCount) كلمات • \(note.content.count) حرف")
                .font(.system(size: 10))
                .foregroundStyle(Color.appMuted)
                .lineLimit(1)
                .fixedSize()

            if showedSavedAt {
                HStack(spacing: 3) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 9))
                    Text("محفوظ")
                        .font(.system(size: 10, weight: .semibold))
                }
                .foregroundStyle(Color(hex: 0x3E7C4F))
                .lineLimit(1)
                .fixedSize()
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(Color.appSidebar.opacity(0.6))
    }

    private var wordCount: Int {
        note.content
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .count
    }

    private func scheduleSave() {
        touch()
        debounceTask?.cancel()
        debounceTask = Task {
            try? await Task.sleep(nanoseconds: 600_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self.note.updatedAt = Date()
                withAnimation { self.showedSavedAt = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation { self.showedSavedAt = false }
                }
            }
        }
    }

    private func touch() {
        note.updatedAt = Date()
        try? context.save()
    }

    private func copyContent() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        let text = [note.displayTitle, note.content].filter { !$0.isBlank }.joined(separator: "\n\n")
        pasteboard.setString(text, forType: .string)
    }
}
