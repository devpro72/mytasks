import SwiftUI
import SwiftData
import AppKit

// MARK: - وحدة العلامة مرجعية

struct BookmarksView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Bookmark.createdAt, order: .reverse) private var bookmarks: [Bookmark]

    @State private var searchText = ""
    @State private var categoryFilter: BookmarkCategory?
    @State private var showEditor = false
    @State private var editingBookmark: Bookmark?

    private var filtered: [Bookmark] {
        var list = bookmarks.sorted {
            if $0.pinned != $1.pinned { return $0.pinned }
            return $0.createdAt > $1.createdAt
        }
        if let category = categoryFilter {
            list = list.filter { $0.category == category }
        }
        if !searchText.isBlank {
            list = list.filter {
                $0.title.localizedStandardContains(searchText) || $0.urlString.localizedStandardContains(searchText)
            }
        }
        return list
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                searchRow
                statsRow
                categoriesAndGrid
            }
            .padding(.horizontal, 26)
            .padding(.top, 20)
            .padding(.bottom, 30)
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .background(Color.appBackground)
        .navigationTitle("العلامة مرجعية")
        .sheet(isPresented: $showEditor) {
            BookmarkEditor()
        }
        .sheet(item: $editingBookmark) { bookmark in
            BookmarkEditor(bookmark: bookmark)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("العلامات السريعة")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(Color.appText)
            Text("روابطك المرجعية ووثائقك في مكان واحد، بفتح فوري.")
                .font(.system(size: 12))
                .foregroundStyle(Color.appMuted)
        }
    }

    private var searchRow: some View {
        HStack(spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.appMuted)
                TextField("ابحث في الروابط أو النطاقات...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .frame(minWidth: 200, idealWidth: 340, maxWidth: 420)
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.appField))

            Spacer()

            Button {
                showEditor = true
            } label: {
                Label("إضافة رابط", systemImage: "plus")
                    .font(.system(size: 12, weight: .semibold))
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.appAccent)
        }
    }

    private var statsRow: some View {
        HStack(spacing: 12) {
            StatCard(icon: "bookmark.fill",
                     tint: Color.appAccent,
                     value: "\(bookmarks.count)",
                     title: "مجموع العلامات",
                     subtitle: "كل الروابط المحفوظة")
            StatCard(icon: "pin.fill",
                     tint: Color(hex: 0xC08A3E),
                     value: "\(bookmarks.filter { $0.pinned }.count)",
                     title: "مثبّتة",
                     subtitle: "في الوصول السريع")
            StatCard(icon: "arrow.up.forward.square.fill",
                     tint: Color(hex: 0x3E7C4F),
                     value: "\(bookmarks.reduce(0) { $0 + $1.launchCount })",
                     title: "مرات الفتح",
                     subtitle: "مجموع كل عمليات الفتح")
        }
    }

    private var categoriesAndGrid: some View {
        VStack(alignment: .leading, spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    chip(label: "الكل", count: bookmarks.count, isSelected: categoryFilter == nil) {
                        categoryFilter = nil
                    }
                    ForEach(BookmarkCategory.allCases) { category in
                        chip(label: category.label,
                             count: bookmarks.filter { $0.category == category }.count,
                             isSelected: categoryFilter == category) {
                            categoryFilter = categoryFilter == category ? nil : category
                        }
                    }
                }
            }

            if filtered.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "bookmark")
                        .font(.system(size: 30))
                        .foregroundStyle(Color.appMuted.opacity(0.5))
                    Text("لا توجد علامات بعد — اضغط «إضافة رابط» للبدء")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.appMuted)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 36)
                .surface()
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 250, maximum: 300), spacing: 12)], spacing: 12) {
                    ForEach(filtered) { bookmark in
                        BookmarkCard(bookmark: bookmark, onEdit: { editingBookmark = bookmark })
                    }
                }
            }
        }
    }

    private func chip(label: String, count: Int, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(label)
                    .font(.system(size: 11, weight: isSelected ? .bold : .medium))
                Text("\(count)")
                    .font(.system(size: 10, weight: .semibold))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(Capsule().fill(isSelected ? Color.white.opacity(0.25) : Color.appMuted.opacity(0.15)))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule().fill(isSelected ? Color.appAccent : Color.appCard))
            .overlay(Capsule().strokeBorder(isSelected ? Color.clear : Color.appBorder, lineWidth: 1))
            .foregroundStyle(isSelected ? Color.white : Color.appText)
        }
        .buttonStyle(.press)
    }
}

// MARK: - بطاقة علامة مرجعية

struct BookmarkCard: View {
    @Environment(\.modelContext) private var context
    let bookmark: Bookmark
    let onEdit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 9) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.appAccentSoft)
                    Image(systemName: "globe")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.appAccent)
                }
                .frame(width: 30, height: 30)

                VStack(alignment: .leading, spacing: 2) {
                    Text(bookmark.title)
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(Color.appText)
                        .lineLimit(1)
                    Text(bookmark.domain)
                        .font(.system(size: 10))
                        .foregroundStyle(Color.appMuted)
                        .lineLimit(1)
                }
                Spacer()
                if bookmark.pinned {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(Color(hex: 0xC08A3E))
                }
            }

            ChipView(label: bookmark.category.label, icon: nil, color: Color.appAccent)

            Divider().overlay(Color.appBorder)

            HStack(spacing: 8) {
                Button {
                    openLink()
                } label: {
                    Label("فتح الرابط", systemImage: "arrow.up.forward")
                        .font(.system(size: 11, weight: .semibold))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(Color.appAccent)

                Text(bookmark.launchCount == 0 ? "لم يُفتح بعد" : "فُتح \(bookmark.launchCount) مرة")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.appMuted)

                Spacer()

                Button {
                    bookmark.pinned.toggle()
                    try? context.save()
                } label: {
                    Image(systemName: bookmark.pinned ? "pin.fill" : "pin")
                        .font(.system(size: 11))
                        .foregroundStyle(bookmark.pinned ? Color(hex: 0xC08A3E) : Color.appMuted)
                        .padding(3)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.press)

                Button {
                    context.delete(bookmark)
                    try? context.save()
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                        .foregroundStyle(Color(hex: 0xC25450))
                        .padding(3)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.press)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .surface()
        .onTapGesture(count: 2) { onEdit() }
        .help("نقرة مزدوجة للتعديل")
        .contextMenu {
            Button("تعديل العلامة") { onEdit() }
            Button("فتح الرابط") { openLink() }
            Divider()
            Button("حذف", role: .destructive) {
                context.delete(bookmark)
                try? context.save()
            }
        }
    }

    private func openLink() {
        guard let url = bookmark.url else { return }
        NSWorkspace.shared.open(url)
        bookmark.launchCount += 1
        try? context.save()
    }
}

// MARK: - محرر علامة مرجعية (بدون Form)

struct BookmarkEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    /// nil = إضافة جديدة — وجود العلامة = تعديل
    let bookmark: Bookmark?

    @State private var title = ""
    @State private var urlString = ""
    @State private var category = BookmarkCategory.reference
    @State private var isPinned = false

    init(bookmark: Bookmark? = nil) {
        self.bookmark = bookmark
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(bookmark == nil ? "علامة جديدة" : "تعديل العلامة")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(Color.appSidebar)

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 6) {
                        FieldLabel(text: "العنوان")
                        StyledTextField(placeholder: "مثال: وثائق سويفت الرسمية", text: $title)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        FieldLabel(text: "الرابط")
                        StyledTextField(placeholder: "", text: $urlString)
                            .onSubmit { save() }
                    }

                    MenuPicker(label: "التصنيف",
                               selection: $category,
                               options: BookmarkCategory.allCases.map { ($0, $0.label) })

                    HStack {
                        Text("تثبيت في الوصول السريع")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color.appText)
                        Spacer()
                        Toggle("", isOn: $isPinned)
                            .toggleStyle(.switch)
                            .labelsHidden()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.appField)
                    )
                }
                .padding(18)
            }

            HStack {
                Spacer()
                Button("إلغاء") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(bookmark == nil ? "إضافة" : "حفظ التعديل") { save() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .tint(Color.appAccent)
                    .disabled(title.isBlank || urlString.isBlank)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color.appSidebar)
        }
        .frame(minWidth: 400, idealWidth: 430, minHeight: 340, idealHeight: 400)
        .applyAppearance()
        .forceRTL()
        .onAppear {
            if let b = bookmark {
                title = b.title
                urlString = b.urlString
                category = b.category
                isPinned = b.pinned
            }
        }
    }

    private func save() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        var link = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isBlank, !link.isBlank else { return }
        if !link.contains("://") { link = "https://" + link }

        if let existing = bookmark {
            existing.title = trimmedTitle
            existing.urlString = link
            existing.category = category
            existing.pinned = isPinned
        } else {
            context.insert(Bookmark(title: trimmedTitle, urlString: link, category: category, pinned: isPinned))
        }
        try? context.save()
        dismiss()
    }
}
