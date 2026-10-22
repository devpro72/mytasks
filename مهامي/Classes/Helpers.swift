import Foundation
import SwiftUI

/// الإعدادات المحلية الموحّدة: لغة عربية + أرقام غربية (1234567890) دائمًا
/// لا تُستخدم الأرقام الهندية (١٢٣) في أي مكان بالتطبيق.
enum AppLocale {
    static let identifier = "ar-EG-u-nu-latn"
    static let locale = Locale(identifier: identifier)
}

extension DateFormatter {
    static func arabic(_ template: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = AppLocale.locale
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.setLocalizedDateFormatFromTemplate(template)
        return formatter
    }
}

/// منسّقات تاريخ موحّدة
enum Fmt {
    /// "30 أكتوبر"
    static let dayMonth = DateFormatter.arabic("d MMMM")
    /// "30 أكتوبر 2026"
    static let dayMonthYear = DateFormatter.arabic("d MMMM yyyy")
    /// "أكتوبر 2026"
    static let monthYear = DateFormatter.arabic("MMMM yyyy")
    /// "14:30"
    static let time = DateFormatter.arabic("HH:mm")
    /// "30 أكتوبر 2026 • 14:30"
    static let full = DateFormatter.arabic("d MMMM yyyy • HH:mm")

    static let weekdaySymbols: [String] = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = AppLocale.locale
        // الأسبوع يبدأ بالسبت (7)
        var symbols = calendar.shortStandaloneWeekdaySymbols
        let saturday = symbols.removeLast()
        symbols.insert(saturday, at: 0)
        return symbols
    }()

    static func due(_ date: Date) -> String { dayMonth.string(from: date) }
    static func relativeTime(_ date: Date) -> String {
        relativeFormatter.localizedString(fromTimeInterval: date.timeIntervalSinceNow)
    }

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = AppLocale.locale
        formatter.dateTimeStyle = .named
        return formatter
    }()
}

enum Cal {
    static let gregorian: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 7 // السبت
        calendar.locale = AppLocale.locale
        return calendar
    }()

    static func startOfMonth(_ date: Date) -> Date {
        let components = gregorian.dateComponents([.year, .month], from: date)
        return gregorian.date(from: components) ?? date
    }

    static func startOfDay(_ date: Date) -> Date {
        gregorian.startOfDay(for: date)
    }

    static func addMonths(_ count: Int, to date: Date) -> Date {
        gregorian.date(byAdding: .month, value: count, to: date) ?? date
    }
}

extension String {
    var isBlank: Bool { trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
}

enum AppInfo {
    static let name = "مهامي"
    static let subtitle = "إدارة المهام والمشاريع والملاحظات — بالكامل بالعربية"
    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }
}
