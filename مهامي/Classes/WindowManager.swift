import AppKit
import Combine

/// يدير نافذة «الملاحظة السريعة» العائمة: إظهارها وإخفائها من زر التبديل في النافذة الرئيسية.
final class WindowManager: ObservableObject {
    static let shared = WindowManager()

    @Published private(set) var isQuickNoteVisible = false

    private weak var quickWindow: NSWindow?

    func registerQuickNote(_ window: NSWindow?) {
        quickWindow = window
        isQuickNoteVisible = window != nil
        guard let window else { return }
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    }

    func unregisterQuickNote() {
        quickWindow = nil
        isQuickNoteVisible = false
    }

    func hideQuickNote() {
        quickWindow?.performClose(nil)
        quickWindow = nil
        isQuickNoteVisible = false
    }
}
