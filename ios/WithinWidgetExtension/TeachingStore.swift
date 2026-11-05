import Foundation

struct Teaching: Codable, Hashable, Identifiable {
    let id: String
    let tradition: String
    let scripture: String
    let reference: String
    let text: String
    let shortText: String
    let contentType: String
    let language: String
    let attribution: String?
}

private struct TeachingLibrary: Codable {
    let tradition: String
    let version: Int
    let teachings: [Teaching]
}

/// Native mirror of `lib/services/teaching_service.dart`. The selection rule
/// must stay identical so the app and widgets always show the same teaching:
///
///   dayNumber = whole days from 2025-01-01 to the local calendar date
///   index     = dayNumber mod teachings.count  (teachings sorted by id)
struct TeachingStore {
    let teachings: [Teaching]

    init(teachings: [Teaching]) {
        self.teachings = teachings.sorted { $0.id < $1.id }
    }

    /// Loads the JSON copied into the extension bundle from `assets/teachings/`.
    static func load(tradition: String = "buddhism", bundle: Bundle = .main) -> TeachingStore? {
        guard
            let url = bundle.url(forResource: tradition, withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let library = try? JSONDecoder().decode(TeachingLibrary.self, from: data),
            !library.teachings.isEmpty
        else { return nil }
        return TeachingStore(teachings: library.teachings)
    }

    /// The user's local calendar, forced to Gregorian so the date components
    /// match Dart's `DateTime` even when the device uses e.g. the Buddhist calendar.
    static var localCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        return calendar
    }

    private static let utcCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    private static let epoch = utcCalendar.date(from: DateComponents(year: 2025, month: 1, day: 1))!

    /// Whole calendar days between 2025-01-01 and `date`'s local Y/M/D. Only the
    /// date components are used, re-anchored in UTC, so DST can't shift the result.
    static func dayNumber(for date: Date, calendar: Calendar = localCalendar) -> Int {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let day = utcCalendar.date(from: components)!
        return utcCalendar.dateComponents([.day], from: epoch, to: day).day!
    }

    func teaching(for date: Date, calendar: Calendar = localCalendar) -> Teaching {
        let count = teachings.count
        // Swift's % keeps the sign, so normalise for dates before the epoch.
        let index = ((Self.dayNumber(for: date, calendar: calendar) % count) + count) % count
        return teachings[index]
    }
}
